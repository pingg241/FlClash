#include "proxy_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <WinInet.h>
#include <Ras.h>
#include <RasError.h>
#include <vector>
#include <iostream>
#include <string>

#pragma comment(lib, "wininet")
#pragma comment(lib, "Rasapi32")

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace
{
bool ApplyConnectionOptions(INTERNET_PER_CONN_OPTION_LIST& list)
{
  const DWORD buffer_size = sizeof(list);
  list.pszConnection = nullptr;
  const auto applied_default =
      InternetSetOption(nullptr, INTERNET_OPTION_PER_CONNECTION_OPTION, &list, buffer_size) ==
      TRUE;

  DWORD size = sizeof(RASENTRYNAME);
  DWORD count = 0;
  std::vector<RASENTRYNAME> entries(1);
  entries[0].dwSize = sizeof(RASENTRYNAME);

  auto ret = RasEnumEntries(nullptr, nullptr, entries.data(), &size, &count);
  if (ret == ERROR_BUFFER_TOO_SMALL)
  {
    entries.assign(size / sizeof(RASENTRYNAME), RASENTRYNAME{});
    for (auto& entry : entries)
    {
      entry.dwSize = sizeof(RASENTRYNAME);
    }
    ret = RasEnumEntries(nullptr, nullptr, entries.data(), &size, &count);
  }

  auto applied_connections = true;
  if (ret == ERROR_SUCCESS)
  {
    for (DWORD i = 0; i < count; i++)
    {
      list.pszConnection = entries[i].szEntryName;
      applied_connections =
          InternetSetOption(nullptr, INTERNET_OPTION_PER_CONNECTION_OPTION, &list, buffer_size) ==
              TRUE &&
          applied_connections;
    }
  }

  InternetSetOption(nullptr, INTERNET_OPTION_SETTINGS_CHANGED, nullptr, 0);
  InternetSetOption(nullptr, INTERNET_OPTION_REFRESH, nullptr, 0);
  return applied_default && applied_connections;
}

void startProxy(const int port, const flutter::EncodableList& bypassDomain)
{
  std::wstring proxy_server =
      std::wstring(L"127.0.0.1:") + std::to_wstring(port);
  std::wstring bypass_list;
  for (const auto& domain : bypassDomain)
  {
    if (!bypass_list.empty())
    {
      bypass_list += L";";
    }
    const auto& value = std::get<std::string>(domain);
    bypass_list += std::wstring(value.begin(), value.end());
  }

  std::vector<INTERNET_PER_CONN_OPTION> options(3);
  options[0].dwOption = INTERNET_PER_CONN_FLAGS;
  options[0].Value.dwValue = PROXY_TYPE_DIRECT | PROXY_TYPE_PROXY;
  options[1].dwOption = INTERNET_PER_CONN_PROXY_SERVER;
  options[1].Value.pszValue = const_cast<LPWSTR>(proxy_server.c_str());
  options[2].dwOption = INTERNET_PER_CONN_PROXY_BYPASS;
  options[2].Value.pszValue = const_cast<LPWSTR>(bypass_list.c_str());

  INTERNET_PER_CONN_OPTION_LIST list{};
  list.dwSize = sizeof(list);
  list.dwOptionCount = static_cast<DWORD>(options.size());
  list.pOptions = options.data();
  ApplyConnectionOptions(list);
}

void stopProxy()
{
  std::wstring empty_value;
  std::vector<INTERNET_PER_CONN_OPTION> options(4);
  options[0].dwOption = INTERNET_PER_CONN_FLAGS;
  options[0].Value.dwValue = PROXY_TYPE_DIRECT;
  options[1].dwOption = INTERNET_PER_CONN_PROXY_SERVER;
  options[1].Value.pszValue = const_cast<LPWSTR>(empty_value.c_str());
  options[2].dwOption = INTERNET_PER_CONN_PROXY_BYPASS;
  options[2].Value.pszValue = const_cast<LPWSTR>(empty_value.c_str());
  options[3].dwOption = INTERNET_PER_CONN_AUTOCONFIG_URL;
  options[3].Value.pszValue = const_cast<LPWSTR>(empty_value.c_str());

  INTERNET_PER_CONN_OPTION_LIST list{};
  list.dwSize = sizeof(list);
  list.dwOptionCount = static_cast<DWORD>(options.size());
  list.pOptions = options.data();
  ApplyConnectionOptions(list);
}
}  // namespace

namespace proxy
{

  // static
  void ProxyPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar)
  {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "proxy",
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<ProxyPlugin>();

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto &call, auto result)
        {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  ProxyPlugin::ProxyPlugin() {}

  ProxyPlugin::~ProxyPlugin() {}

  void ProxyPlugin::HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    if (method_call.method_name().compare("StopProxy") == 0)
    {
      stopProxy();
      result->Success(true);
    }
    else if (method_call.method_name().compare("StartProxy") == 0)
    {
      auto *arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      auto port = std::get<int>(arguments->at(flutter::EncodableValue("port")));
      auto bypassDomain = std::get<flutter::EncodableList>(arguments->at(flutter::EncodableValue("bypassDomain")));
      startProxy(port, bypassDomain);
      result->Success(true);
    }
    else
    {
      result->NotImplemented();
    }
  }
} // namespace proxy
