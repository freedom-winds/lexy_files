#include "bluetooth_status_channel.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <bluetoothapis.h>

#include <memory>
#include <string>

namespace {

std::string WideToUtf8(const wchar_t* value) {
  if (value == nullptr || value[0] == L'\0') {
    return "";
  }

  const int size = WideCharToMultiByte(CP_UTF8, 0, value, -1, nullptr, 0,
                                       nullptr, nullptr);
  if (size <= 1) {
    return "";
  }

  std::string result(size - 1, '\0');
  WideCharToMultiByte(CP_UTF8, 0, value, -1, result.data(), size, nullptr,
                      nullptr);
  return result;
}

flutter::EncodableValue GetBluetoothState() {
  BLUETOOTH_FIND_RADIO_PARAMS params = {sizeof(BLUETOOTH_FIND_RADIO_PARAMS)};
  HANDLE radio = nullptr;
  HBLUETOOTH_RADIO_FIND finder = BluetoothFindFirstRadio(&params, &radio);

  bool available = false;
  bool connectable = false;
  std::string name;

  if (finder != nullptr && radio != nullptr) {
    available = true;
    connectable = BluetoothIsConnectable(radio) == TRUE;

    BLUETOOTH_RADIO_INFO info = {sizeof(BLUETOOTH_RADIO_INFO)};
    if (BluetoothGetRadioInfo(radio, &info) == ERROR_SUCCESS) {
      name = WideToUtf8(info.szName);
    }

    CloseHandle(radio);
    BluetoothFindRadioClose(finder);
  }

  flutter::EncodableMap state;
  state[flutter::EncodableValue("available")] =
      flutter::EncodableValue(available);
  state[flutter::EncodableValue("poweredOn")] =
      flutter::EncodableValue(available);
  state[flutter::EncodableValue("connectable")] =
      flutter::EncodableValue(connectable);
  state[flutter::EncodableValue("name")] = flutter::EncodableValue(name);
  return flutter::EncodableValue(state);
}

}  // namespace

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
RegisterBluetoothStatusChannel(flutter::BinaryMessenger* messenger) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "lexy_files/windows_bluetooth",
      &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() == "getBluetoothState") {
          result->Success(GetBluetoothState());
        } else {
          result->NotImplemented();
        }
      });

  return channel;
}
