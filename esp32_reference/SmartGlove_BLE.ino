/*
 * SmartGlove ESP32 - BLE Vibration Controller
 * 
 * This Arduino sketch creates a BLE GATT server that receives
 * vibration commands from the Flutter navigation app.
 * 
 * Hardware Setup:
 * - Left vibration motor: GPIO 25
 * - Right vibration motor: GPIO 26
 * - Use transistors (e.g., 2N2222) to drive motors
 */

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// BLE UUIDs (must match Flutter app)
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Hardware pins
#define VIBRATE_PIN_LEFT  25
#define VIBRATE_PIN_RIGHT 26

BLECharacteristic *pCharacteristic;
bool deviceConnected = false;

// Callback when client connects/disconnects
class MyServerCallbacks: public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("Client connected");
  }

  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("Client disconnected");
    // Restart advertising
    BLEDevice::startAdvertising();
  }
};

// Callback when data is received
class MyCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    std::string value = pCharacteristic->getValue();
    
    if (value.length() > 0) {
      uint8_t command = value[0];
      Serial.printf("Received command: %d\n", command);
      
      switch(command) {
        case 1: // 右轉 - Right turn
          vibrateRight();
          break;
        case 2: // 左轉 - Left turn
          vibrateLeft();
          break;
        case 3: // 直行 - Straight
          vibrateBoth();
          break;
        case 0: // 停止 - Stop
          stopAll();
          break;
      }
    }
  }
};

void setup() {
  Serial.begin(115200);
  Serial.println("SmartGlove BLE Server starting...");

  // Setup motor pins
  pinMode(VIBRATE_PIN_LEFT, OUTPUT);
  pinMode(VIBRATE_PIN_RIGHT, OUTPUT);
  digitalWrite(VIBRATE_PIN_LEFT, LOW);
  digitalWrite(VIBRATE_PIN_RIGHT, LOW);

  // Initialize BLE
  BLEDevice::init("SmartGlove");
  
  // Create BLE Server
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create BLE Characteristic
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_WRITE
  );

  pCharacteristic->setCallbacks(new MyCallbacks());
  pCharacteristic->addDescriptor(new BLE2902());

  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();

  Serial.println("SmartGlove is ready and advertising!");
}

void loop() {
  delay(1000);
}

// Vibration functions
void vibrateRight() {
  Serial.println("📳 Right turn!");
  digitalWrite(VIBRATE_PIN_RIGHT, HIGH);
  delay(500);
  digitalWrite(VIBRATE_PIN_RIGHT, LOW);
}

void vibrateLeft() {
  Serial.println("📳 Left turn!");
  digitalWrite(VIBRATE_PIN_LEFT, HIGH);
  delay(500);
  digitalWrite(VIBRATE_PIN_LEFT, LOW);
}

void vibrateBoth() {
  Serial.println("📳 Straight ahead!");
  digitalWrite(VIBRATE_PIN_LEFT, HIGH);
  digitalWrite(VIBRATE_PIN_RIGHT, HIGH);
  delay(200);
  digitalWrite(VIBRATE_PIN_LEFT, LOW);
  digitalWrite(VIBRATE_PIN_RIGHT, LOW);
}

void stopAll() {
  digitalWrite(VIBRATE_PIN_LEFT, LOW);
  digitalWrite(VIBRATE_PIN_RIGHT, LOW);
}
