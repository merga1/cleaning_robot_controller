/*
 * CleanBot base controller firmware (ESP32 / Arduino)
 * ---------------------------------------------------
 * Speaks the newline-delimited JSON protocol implemented on the Raspberry Pi
 * by `cleanbot_hardware/serial_protocol.py`.
 *
 * Libraries (Arduino IDE -> Library Manager):
 *   - ArduinoJson (>= 6.21)
 *
 * Board: "ESP32 Dev Module", 115200 baud monitor, 240 MHz.
 *
 * Serial protocol
 *   Pi -> ESP32   {"v":1,"type":"cmd_vel","linear":0.2,"angular":0.0}
 *                 {"v":1,"type":"stop"}
 *                 {"v":1,"type":"estop","engage":true}
 *                 {"v":1,"type":"cleaning","enabled":true,"mode":"standard","speed":1.0}
 *                 {"v":1,"type":"request_status"}
 *   ESP32 -> Pi   {"type":"telemetry","left_ticks":..,"right_ticks":..,...}
 *                 {"type":"hello","firmware":"cleanbot-esp32-1.0.0"}
 *                 {"type":"ack","cmd":"cmd_vel"}
 *                 {"type":"event","event":"cliff"}
 *
 * Pin map (change to match your harness)
 *   Motor driver (L298N / BTS7960 logic pins)
 *     Left  IN1 25, IN2 26, ENA(PWM) 33
 *     Right IN3 27, IN4 14, ENB(PWM) 32
 *   Wheel encoders (quadrature, external 10k pull-ups recommended)
 *     Left  A 34, B 35
 *     Right A 36, B 39
 *   Battery divider sense  4   (ADC1, 0-3.3 V, divider must stay < 3.3 V)
 *   Waste ultrasonic       TRIG 5, ECHO 18
 *   Cliff sensors (active LOW) 16, 17, 19
 *   Bumper (active LOW)    23
 *   E-stop button (NC, active LOW) 21
 *   Charging detect (active LOW)   22
 *   Cleaning relay / MOSFET gate   13
 *   Status LED                     2
 */

#include <Arduino.h>
#include <ArduinoJson.h>

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------
static const char *FIRMWARE_VERSION = "cleanbot-esp32-1.0.0";
static const uint32_t SERIAL_BAUD = 115200;

// Differential drive geometry (must match hardware.yaml).
static const float WHEEL_RADIUS_M = 0.065f;
static const float WHEEL_SEPARATION_M = 0.34f;
static const float TICKS_PER_REVOLUTION = 1320.0f;
static const float MAX_LINEAR_MPS = 0.55f;
static const float MAX_ANGULAR_RPS = 1.8f;

// Control loop / telemetry timing.
static const uint32_t CONTROL_PERIOD_MS = 20;    // 50 Hz
static const uint32_t TELEMETRY_PERIOD_MS = 50;  // 20 Hz
static const uint32_t COMMAND_TIMEOUT_MS = 600;

// Battery divider: R1 = 100k, R2 = 33k -> ratio (R1 + R2) / R2.
static const float BATTERY_DIVIDER_RATIO = (100.0f + 33.0f) / 33.0f;
static const float ADC_REFERENCE_V = 3.3f;
static const float BATTERY_MIN_V = 9.6f;
static const float BATTERY_MAX_V = 12.6f;

// Motor PWM
static const int PWM_FREQUENCY = 20000;
static const int PWM_RESOLUTION = 8;
static const int PWM_MAX = 255;

// ---------------------------------------------------------------------------
// Pin map
// ---------------------------------------------------------------------------
const int PIN_L_IN1 = 25;
const int PIN_L_IN2 = 26;
const int PIN_L_EN = 33;
const int PIN_R_IN3 = 27;
const int PIN_R_IN4 = 14;
const int PIN_R_EN = 32;

const int PIN_ENC_L_A = 34;
const int PIN_ENC_L_B = 35;
const int PIN_ENC_R_A = 36;
const int PIN_ENC_R_B = 39;

const int PIN_BATTERY = 4;
const int PIN_WASTE_TRIG = 5;
const int PIN_WASTE_ECHO = 18;
const int PIN_CLIFF[3] = {16, 17, 19};
const int PIN_BUMPER = 23;
const int PIN_ESTOP = 21;
const int PIN_CHARGING = 22;
const int PIN_CLEANING_RELAY = 13;
const int PIN_LED = 2;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
volatile long g_leftTicks = 0;
volatile long g_rightTicks = 0;
volatile int g_leftDir = 0;
volatile int g_rightDir = 0;

float g_targetLinear = 0.0f;
float g_targetAngular = 0.0f;
uint32_t g_lastCommandAt = 0;

bool g_estopLatched = false;
bool g_cleaningEnabled = false;
String g_cleaningMode = "standard";
float g_cleaningSpeed = 1.0f;

float g_batteryVoltage = 0.0f;
int g_wasteFill = 0;
bool g_wasteFault = false;
bool g_cliff = false;
bool g_bumper = false;
bool g_charging = false;

uint32_t g_lastControlAt = 0;
uint32_t g_lastTelemetryAt = 0;
String g_rxBuffer;

// ---------------------------------------------------------------------------
// Encoder interrupts
// ---------------------------------------------------------------------------
void IRAM_ATTR leftEncoderISR() {
  int a = digitalRead(PIN_ENC_L_A);
  int b = digitalRead(PIN_ENC_L_B);
  g_leftTicks += (a == b) ? 1 : -1;
}

void IRAM_ATTR rightEncoderISR() {
  int a = digitalRead(PIN_ENC_R_A);
  int b = digitalRead(PIN_ENC_R_B);
  g_rightTicks += (a == b) ? 1 : -1;
}

// ---------------------------------------------------------------------------
// Motor helpers
// ---------------------------------------------------------------------------
void setMotorPwm(int pinEn, int pinIn1, int pinIn2, float command) {
  command = constrain(command, -1.0f, 1.0f);
  int pwm = (int)(fabsf(command) * PWM_MAX);
  if (command > 0.01f) {
    digitalWrite(pinIn1, HIGH);
    digitalWrite(pinIn2, LOW);
  } else if (command < -0.01f) {
    digitalWrite(pinIn1, LOW);
    digitalWrite(pinIn2, HIGH);
  } else {
    digitalWrite(pinIn1, LOW);
    digitalWrite(pinIn2, LOW);
    pwm = 0;
  }
  ledcWrite(pinEn, pwm);
}

void stopMotors() {
  g_targetLinear = 0.0f;
  g_targetAngular = 0.0f;
  setMotorPwm(PIN_L_EN, PIN_L_IN1, PIN_L_IN2, 0.0f);
  setMotorPwm(PIN_R_EN, PIN_R_IN3, PIN_R_IN4, 0.0f);
}

void setCleaning(bool enabled) {
  g_cleaningEnabled = enabled;
  digitalWrite(PIN_CLEANING_RELAY, enabled ? HIGH : LOW);
}

// ---------------------------------------------------------------------------
// Sensors
// ---------------------------------------------------------------------------
float readBatteryVoltage() {
  // Average a few samples to reject motor noise.
  uint32_t total = 0;
  for (int i = 0; i < 16; i++) {
    total += analogRead(PIN_BATTERY);
    delayMicroseconds(150);
  }
  float adc = total / 16.0f;
  float pinVoltage = (adc / 4095.0f) * ADC_REFERENCE_V;
  return pinVoltage * BATTERY_DIVIDER_RATIO;
}

int readWasteFillPercent() {
  digitalWrite(PIN_WASTE_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(PIN_WASTE_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(PIN_WASTE_TRIG, LOW);

  unsigned long duration = pulseIn(PIN_WASTE_ECHO, HIGH, 30000UL);
  if (duration == 0) {
    g_wasteFault = true;
    return g_wasteFill;
  }
  g_wasteFault = false;

  // Container is 40 cm deep; 4 cm from the lid means empty, 36 cm means full.
  float distanceCm = (duration * 0.0343f) / 2.0f;
  float fill = (distanceCm - 4.0f) / 32.0f * 100.0f;
  return (int)constrain(fill, 0.0f, 100.0f);
}

bool anyCliff() {
  for (int i = 0; i < 3; i++) {
    if (digitalRead(PIN_CLIFF[i]) == LOW) {
      return true;
    }
  }
  return false;
}

void updateSafetyInputs() {
  g_cliff = anyCliff();
  g_bumper = digitalRead(PIN_BUMPER) == LOW;
  g_charging = digitalRead(PIN_CHARGING) == LOW;

  if (digitalRead(PIN_ESTOP) == LOW) {
    g_estopLatched = true;
  }
  if (g_cliff || g_bumper || g_estopLatched) {
    stopMotors();
    setCleaning(false);
    digitalWrite(PIN_LED, (millis() / 100) % 2);  // fast blink
  }
}

// ---------------------------------------------------------------------------
// Command handling
// ---------------------------------------------------------------------------
void sendJson(JsonDocument &doc) {
  serializeJson(doc, Serial);
  Serial.print('\n');
}

void sendAck(const char *command) {
  StaticJsonDocument<96> doc;
  doc["type"] = "ack";
  doc["cmd"] = command;
  sendJson(doc);
}

void sendEvent(const char *event) {
  StaticJsonDocument<96> doc;
  doc["type"] = "event";
  doc["event"] = event;
  sendJson(doc);
}

void sendTelemetry() {
  StaticJsonDocument<384> doc;
  doc["type"] = "telemetry";
  doc["firmware"] = FIRMWARE_VERSION;
  doc["left_ticks"] = (long)g_leftTicks;
  doc["right_ticks"] = (long)g_rightTicks;
  doc["battery_voltage"] = round(g_batteryVoltage * 100.0f) / 100.0f;
  doc["charging"] = g_charging;
  doc["estop"] = g_estopLatched;
  doc["brush"] = g_cleaningEnabled;
  doc["waste_fill"] = g_wasteFill;
  doc["waste_sensor_fault"] = g_wasteFault;
  doc["cliff"] = g_cliff;
  doc["bumper"] = g_bumper;
  doc["uptime_ms"] = millis();
  sendJson(doc);
}

void handleCommand(const String &line) {
  StaticJsonDocument<384> doc;
  DeserializationError error = deserializeJson(doc, line);
  if (error) {
    return;
  }

  const char *type = doc["type"] | "";
  if (strcmp(type, "cmd_vel") == 0) {
    if (g_estopLatched) {
      stopMotors();
      return;
    }
    g_targetLinear = constrain((float)(doc["linear"] | 0.0f),
                               -MAX_LINEAR_MPS, MAX_LINEAR_MPS);
    g_targetAngular = constrain((float)(doc["angular"] | 0.0f),
                                -MAX_ANGULAR_RPS, MAX_ANGULAR_RPS);
    g_lastCommandAt = millis();
    return;
  }

  if (strcmp(type, "stop") == 0) {
    stopMotors();
    return;
  }

  if (strcmp(type, "estop") == 0) {
    bool engage = doc["engage"] | true;
    if (engage) {
      g_estopLatched = true;
      stopMotors();
      setCleaning(false);
      sendEvent("estop_engaged");
    } else if (digitalRead(PIN_ESTOP) == HIGH) {
      g_estopLatched = false;
      digitalWrite(PIN_LED, LOW);
      sendEvent("estop_released");
    } else {
      sendEvent("estop_still_pressed");
    }
    sendAck("estop");
    return;
  }

  if (strcmp(type, "cleaning") == 0) {
    bool enable = doc["enabled"] | false;
    if (g_estopLatched || g_cliff || g_bumper) {
      enable = false;
    }
    g_cleaningMode = String((const char *)(doc["mode"] | "standard"));
    g_cleaningSpeed = constrain((float)(doc["speed"] | 1.0f), 0.1f, 1.0f);
    setCleaning(enable);
    sendAck("cleaning");
    return;
  }

  if (strcmp(type, "request_status") == 0) {
    sendTelemetry();
    return;
  }

  if (strcmp(type, "ping") == 0) {
    sendAck("ping");
    return;
  }

  sendAck(type);
}

void pollSerial() {
  while (Serial.available() > 0) {
    char c = (char)Serial.read();
    if (c == '\n' || c == '\r') {
      if (g_rxBuffer.length() > 0) {
        handleCommand(g_rxBuffer);
        g_rxBuffer = "";
      }
    } else if (g_rxBuffer.length() < 512) {
      g_rxBuffer += c;
    }
  }
}

// ---------------------------------------------------------------------------
// Control loop
// ---------------------------------------------------------------------------
void controlLoop() {
  if (g_estopLatched || g_cliff || g_bumper) {
    stopMotors();
    return;
  }

  if (millis() - g_lastCommandAt > COMMAND_TIMEOUT_MS) {
    // Watchdog: Pi stopped talking.
    g_targetLinear = 0.0f;
    g_targetAngular = 0.0f;
  }

  float halfTrack = WHEEL_SEPARATION_M / 2.0f;
  float leftMps = g_targetLinear - g_targetAngular * halfTrack;
  float rightMps = g_targetLinear + g_targetAngular * halfTrack;
  float maxWheel = MAX_LINEAR_MPS + MAX_ANGULAR_RPS * halfTrack;

  leftMps = constrain(leftMps, -maxWheel, maxWheel);
  rightMps = constrain(rightMps, -maxWheel, maxWheel);

  setMotorPwm(PIN_L_EN, PIN_L_IN1, PIN_L_IN2, leftMps / maxWheel);
  setMotorPwm(PIN_R_EN, PIN_R_IN3, PIN_R_IN4, rightMps / maxWheel);
}

// ---------------------------------------------------------------------------
// Arduino entry points
// ---------------------------------------------------------------------------
void setup() {
  Serial.begin(SERIAL_BAUD);
  Serial.setTimeout(50);

  pinMode(PIN_L_IN1, OUTPUT);
  pinMode(PIN_L_IN2, OUTPUT);
  pinMode(PIN_R_IN3, OUTPUT);
  pinMode(PIN_R_IN4, OUTPUT);

  ledcSetup(0, PWM_FREQUENCY, PWM_RESOLUTION);
  ledcAttachPin(PIN_L_EN, 0);
  ledcSetup(1, PWM_FREQUENCY, PWM_RESOLUTION);
  ledcAttachPin(PIN_R_EN, 1);

  pinMode(PIN_ENC_L_A, INPUT);
  pinMode(PIN_ENC_L_B, INPUT);
  pinMode(PIN_ENC_R_A, INPUT);
  pinMode(PIN_ENC_R_B, INPUT);
  attachInterrupt(digitalPinToInterrupt(PIN_ENC_L_A), leftEncoderISR, CHANGE);
  attachInterrupt(digitalPinToInterrupt(PIN_ENC_R_A), rightEncoderISR, CHANGE);

  pinMode(PIN_CLIFF[0], INPUT_PULLUP);
  pinMode(PIN_CLIFF[1], INPUT_PULLUP);
  pinMode(PIN_CLIFF[2], INPUT_PULLUP);
  pinMode(PIN_BUMPER, INPUT_PULLUP);
  pinMode(PIN_ESTOP, INPUT_PULLUP);
  pinMode(PIN_CHARGING, INPUT_PULLUP);

  pinMode(PIN_WASTE_TRIG, OUTPUT);
  pinMode(PIN_WASTE_ECHO, INPUT);
  pinMode(PIN_CLEANING_RELAY, OUTPUT);
  pinMode(PIN_LED, OUTPUT);

  analogReadResolution(12);

  stopMotors();
  setCleaning(false);

  StaticJsonDocument<96> hello;
  hello["type"] = "hello";
  hello["firmware"] = FIRMWARE_VERSION;
  hello["protocol"] = 1;
  sendJson(hello);

  g_lastCommandAt = millis();
  g_batteryVoltage = readBatteryVoltage();
}

void loop() {
  const uint32_t now = millis();

  pollSerial();
  updateSafetyInputs();

  if (now - g_lastControlAt >= CONTROL_PERIOD_MS) {
    g_lastControlAt = now;
    controlLoop();
  }

  if (now - g_lastTelemetryAt >= TELEMETRY_PERIOD_MS) {
    g_lastTelemetryAt = now;
    g_batteryVoltage = readBatteryVoltage();
    g_wasteFill = readWasteFillPercent();
    sendTelemetry();

    bool safetyFault = g_estopLatched || g_cliff || g_bumper;
    digitalWrite(PIN_LED, safetyFault ? ((now / 100) % 2) : HIGH);
  }
}
