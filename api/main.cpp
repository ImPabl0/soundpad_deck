#include <windows.h>
#include <shellapi.h>
#include <winsock2.h>
#include <ws2tcpip.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <mutex>
#include <optional>
#include <regex>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

#pragma comment(lib, "ws2_32.lib")

namespace
{
    constexpr UINT WM_TRAYICON = WM_USER + 1;
    constexpr UINT ID_TRAY_EXIT = 1001;
    constexpr int API_PORT = 1209;
    constexpr int IDI_API_ICON = 201;

    std::atomic<bool> g_running{true};
    std::mutex g_pipeMutex;
    HANDLE g_pipe = INVALID_HANDLE_VALUE;

    std::string trim(const std::string &value)
    {
        size_t start = 0;
        while (start < value.size() && std::isspace(static_cast<unsigned char>(value[start])))
        {
            ++start;
        }

        size_t end = value.size();
        while (end > start && std::isspace(static_cast<unsigned char>(value[end - 1])))
        {
            --end;
        }

        return value.substr(start, end - start);
    }

    std::string toLower(std::string value)
    {
        std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c)
                       { return static_cast<char>(std::tolower(c)); });
        return value;
    }

    std::string jsonEscape(const std::string &input)
    {
        std::ostringstream escaped;
        for (unsigned char c : input)
        {
            switch (c)
            {
            case '\\':
                escaped << "\\\\";
                break;
            case '"':
                escaped << "\\\"";
                break;
            case '\n':
                escaped << "\\n";
                break;
            case '\r':
                escaped << "\\r";
                break;
            case '\t':
                escaped << "\\t";
                break;
            default:
                if (c < 0x20)
                {
                    escaped << "\\u";
                    const char *hex = "0123456789ABCDEF";
                    escaped << '0' << '0' << hex[(c >> 4) & 0xF] << hex[c & 0xF];
                }
                else
                {
                    escaped << static_cast<char>(c);
                }
                break;
            }
        }
        return escaped.str();
    }

    bool ensurePipeConnected()
    {
        if (g_pipe != INVALID_HANDLE_VALUE)
        {
            return true;
        }

        HANDLE pipe = CreateFileW(
            LR"(\\.\pipe\sp_remote_control)",
            GENERIC_READ | GENERIC_WRITE,
            0,
            nullptr,
            OPEN_EXISTING,
            0,
            nullptr);

        if (pipe == INVALID_HANDLE_VALUE)
        {
            return false;
        }

        g_pipe = pipe;
        return true;
    }

    void disconnectPipe()
    {
        if (g_pipe != INVALID_HANDLE_VALUE)
        {
            CloseHandle(g_pipe);
            g_pipe = INVALID_HANDLE_VALUE;
        }
    }

    std::string sendSoundpadRequest(const std::string &request)
    {
        std::lock_guard<std::mutex> lock(g_pipeMutex);

        if (!ensurePipeConnected())
        {
            return "";
        }

        DWORD written = 0;
        if (!WriteFile(g_pipe, request.data(), static_cast<DWORD>(request.size()), &written, nullptr))
        {
            disconnectPipe();
            return "";
        }

        std::string response;
        char buffer[4096];

        // Soundpad writes a short response chunk per request; read until a short tail arrives.
        while (true)
        {
            DWORD readBytes = 0;
            if (!ReadFile(g_pipe, buffer, sizeof(buffer), &readBytes, nullptr))
            {
                disconnectPipe();
                return "";
            }

            if (readBytes == 0)
            {
                break;
            }

            response.append(buffer, buffer + readBytes);
            if (readBytes < sizeof(buffer))
            {
                break;
            }
        }

        return response;
    }

    bool isRequestOk(const std::string &response)
    {
        return response.rfind("R-200", 0) == 0;
    }

    std::filesystem::path getUploadDirectory()
    {
        const char *appData = std::getenv("APPDATA");
        std::filesystem::path base = appData ? std::filesystem::path(appData) : std::filesystem::temp_directory_path();
        std::filesystem::path dir = base / "Soundpad Deck";
        std::error_code ec;
        std::filesystem::create_directories(dir, ec);
        return dir;
    }

    std::vector<std::pair<std::string, std::string>> parseHeaders(const std::string &headersRaw)
    {
        std::vector<std::pair<std::string, std::string>> headers;
        std::istringstream stream(headersRaw);
        std::string line;

        while (std::getline(stream, line))
        {
            if (!line.empty() && line.back() == '\r')
            {
                line.pop_back();
            }
            if (line.empty())
            {
                continue;
            }

            size_t separator = line.find(':');
            if (separator == std::string::npos)
            {
                continue;
            }

            std::string key = toLower(trim(line.substr(0, separator)));
            std::string value = trim(line.substr(separator + 1));
            headers.emplace_back(std::move(key), std::move(value));
        }

        return headers;
    }

    std::optional<std::string> findHeader(
        const std::vector<std::pair<std::string, std::string>> &headers,
        const std::string &key)
    {
        const std::string wanted = toLower(key);
        for (const auto &[k, v] : headers)
        {
            if (k == wanted)
            {
                return v;
            }
        }
        return std::nullopt;
    }

    std::vector<std::pair<int, std::string>> parseSoundsFromXml(const std::string &xml)
    {
        std::vector<std::pair<int, std::string>> sounds;

        std::regex tagRegex(R"(<Sound\b[^>]*>)", std::regex::icase);
        std::regex indexRegex(R"(\bindex\s*=\s*\"(\d+)\")", std::regex::icase);
        std::regex titleRegex(R"(\btitle\s*=\s*\"([^\"]*)\")", std::regex::icase);
        std::regex nameRegex(R"(\bname\s*=\s*\"([^\"]*)\")", std::regex::icase);
        std::regex urlRegex(R"(\burl\s*=\s*\"([^\"]*)\")", std::regex::icase);

        auto begin = std::sregex_iterator(xml.begin(), xml.end(), tagRegex);
        auto end = std::sregex_iterator();

        for (auto it = begin; it != end; ++it)
        {
            const std::string tag = it->str();

            std::smatch indexMatch;
            if (!std::regex_search(tag, indexMatch, indexRegex))
            {
                continue;
            }

            int index = -1;
            try
            {
                index = std::stoi(indexMatch[1].str());
            }
            catch (...)
            {
                continue;
            }

            std::string name;
            std::smatch textMatch;
            if (std::regex_search(tag, textMatch, titleRegex))
            {
                name = textMatch[1].str();
            }
            else if (std::regex_search(tag, textMatch, nameRegex))
            {
                name = textMatch[1].str();
            }
            else if (std::regex_search(tag, textMatch, urlRegex))
            {
                const std::filesystem::path filePath(textMatch[1].str());
                name = filePath.stem().string();
            }
            else
            {
                name = "sound_" + std::to_string(index);
            }

            sounds.emplace_back(index, name);
        }

        return sounds;
    }

    std::string statusJson(const std::string &status, const std::string &message)
    {
        std::ostringstream out;
        out << "{\"status\":\"" << jsonEscape(status)
            << "\",\"message\":\"" << jsonEscape(message) << "\"}";
        return out.str();
    }

    std::string httpResponse(const std::string &body, int statusCode = 200, const std::string &statusText = "OK")
    {
        std::ostringstream response;
        response << "HTTP/1.1 " << statusCode << " " << statusText << "\r\n"
                 << "Content-Type: application/json; charset=utf-8\r\n"
                 << "Content-Length: " << body.size() << "\r\n"
                 << "Connection: close\r\n\r\n"
                 << body;
        return response.str();
    }

    int extractIndexFromPath(const std::string &pathWithQuery)
    {
        const size_t queryPos = pathWithQuery.find('?');
        if (queryPos == std::string::npos)
        {
            return -1;
        }

        const std::string query = pathWithQuery.substr(queryPos + 1);
        const std::string key = "index=";
        const size_t pos = query.find(key);
        if (pos == std::string::npos)
        {
            return -1;
        }

        std::string value = query.substr(pos + key.size());
        const size_t ampersand = value.find('&');
        if (ampersand != std::string::npos)
        {
            value = value.substr(0, ampersand);
        }

        try
        {
            return std::stoi(value);
        }
        catch (...)
        {
            return -1;
        }
    }

    std::string getPathOnly(const std::string &pathWithQuery)
    {
        const size_t queryPos = pathWithQuery.find('?');
        if (queryPos == std::string::npos)
        {
            return pathWithQuery;
        }
        return pathWithQuery.substr(0, queryPos);
    }

    bool parseMultipartFile(
        const std::string &body,
        const std::string &contentType,
        std::string &outFilename,
        std::string &outFileData)
    {
        const std::string boundaryKey = "boundary=";
        const size_t boundaryPos = toLower(contentType).find(boundaryKey);
        if (boundaryPos == std::string::npos)
        {
            return false;
        }

        std::string boundary = "--" + contentType.substr(boundaryPos + boundaryKey.size());
        boundary = trim(boundary);

        const size_t headerStart = body.find("\r\n");
        if (headerStart == std::string::npos)
        {
            return false;
        }

        size_t sectionPos = 0;
        while (true)
        {
            const size_t boundaryStart = body.find(boundary, sectionPos);
            if (boundaryStart == std::string::npos)
            {
                return false;
            }

            const size_t partHeaderStart = body.find("\r\n", boundaryStart);
            if (partHeaderStart == std::string::npos)
            {
                return false;
            }

            const size_t partHeadersEnd = body.find("\r\n\r\n", partHeaderStart + 2);
            if (partHeadersEnd == std::string::npos)
            {
                return false;
            }

            const std::string partHeaders = body.substr(partHeaderStart + 2, partHeadersEnd - (partHeaderStart + 2));
            const std::string partHeadersLower = toLower(partHeaders);
            const bool hasDisposition = partHeadersLower.find("content-disposition") != std::string::npos;
            const bool hasFilename = partHeadersLower.find("filename=") != std::string::npos;

            const size_t dataStart = partHeadersEnd + 4;
            const size_t nextBoundary = body.find(boundary, dataStart);
            if (nextBoundary == std::string::npos)
            {
                return false;
            }

            size_t dataEnd = nextBoundary;
            if (dataEnd >= 2 && body[dataEnd - 2] == '\r' && body[dataEnd - 1] == '\n')
            {
                dataEnd -= 2;
            }

            if (hasDisposition && hasFilename)
            {
                std::regex filenameRegex(R"(filename\s*=\s*\"([^\"]+)\")", std::regex::icase);
                std::smatch match;
                if (!std::regex_search(partHeaders, match, filenameRegex))
                {
                    return false;
                }

                outFilename = std::filesystem::path(match[1].str()).filename().string();
                outFileData = body.substr(dataStart, dataEnd - dataStart);
                return !outFilename.empty();
            }

            sectionPos = nextBoundary + boundary.size();
        }
    }

    std::string handleApiRequest(
        const std::string &method,
        const std::string &pathWithQuery,
        const std::vector<std::pair<std::string, std::string>> &headers,
        const std::string &body,
        bool &outKnownRoute,
        int &outStatusCode,
        std::string &outStatusText)
    {
        outKnownRoute = true;
        outStatusCode = 200;
        outStatusText = "OK";

        const std::string path = getPathOnly(pathWithQuery);

        if (method == "GET" && path == "/health")
        {
            return statusJson("ok", "Soundpad Deck API online");
        }

        if (method == "GET" && path == "/list")
        {
            const std::string xml = sendSoundpadRequest("GetSoundlist()");
            if (xml.empty())
            {
                outStatusCode = 503;
                outStatusText = "Service Unavailable";
                return statusJson("error", "Nao foi possivel conectar no Soundpad.");
            }

            const auto sounds = parseSoundsFromXml(xml);
            std::ostringstream json;
            json << "{\"status\":\"ok\",\"count\":" << sounds.size() << ",\"sounds\":[";
            for (size_t i = 0; i < sounds.size(); ++i)
            {
                if (i > 0)
                {
                    json << ',';
                }
                json << "{\"index\":" << sounds[i].first << ",\"name\":\"" << jsonEscape(sounds[i].second)
                     << "\"}";
            }
            json << "],\"rawXml\":\"" << jsonEscape(xml) << "\"}";
            return json.str();
        }

        if ((method == "GET" || method == "POST") && path == "/play")
        {
            int index = extractIndexFromPath(pathWithQuery);

            if (method == "POST" && index < 0)
            {
                std::regex indexRegex(R"("index"\s*:\s*(\d+))", std::regex::icase);
                std::smatch match;
                if (std::regex_search(body, match, indexRegex))
                {
                    index = std::stoi(match[1].str());
                }
            }

            if (index < 0)
            {
                outStatusCode = 400;
                outStatusText = "Bad Request";
                return statusJson("error", "Informe index via query (?index=) ou JSON {\"index\":N}.");
            }

            const std::string response = sendSoundpadRequest("DoPlaySound(" + std::to_string(index) + ")");
            if (isRequestOk(response))
            {
                return statusJson("ok", "Play enviado ao Soundpad.");
            }

            outStatusCode = 502;
            outStatusText = "Bad Gateway";
            return statusJson("error", response.empty() ? "Soundpad offline." : response);
        }

        if ((method == "GET" || method == "POST") && path == "/pause")
        {
            const std::string state = sendSoundpadRequest("GetPlayStatus()");
            if (state.empty())
            {
                outStatusCode = 503;
                outStatusText = "Service Unavailable";
                return statusJson("error", "Soundpad offline.");
            }

            if (state == "PAUSED")
            {
                return statusJson("ok", "Ja esta pausado.");
            }

            if (state == "PLAYING")
            {
                const std::string response = sendSoundpadRequest("DoTogglePause()");
                if (isRequestOk(response))
                {
                    return statusJson("ok", "Pausado com sucesso.");
                }
                outStatusCode = 502;
                outStatusText = "Bad Gateway";
                return statusJson("error", response.empty() ? "Falha na chamada ao Soundpad." : response);
            }

            return statusJson("ok", "Nenhum audio em execucao.");
        }

        if ((method == "GET" || method == "POST") && path == "/stop")
        {
            const std::string response = sendSoundpadRequest("DoStopSound()");
            if (response.empty())
            {
                outStatusCode = 503;
                outStatusText = "Service Unavailable";
                return statusJson("error", "Soundpad offline.");
            }

            if (isRequestOk(response))
            {
                return statusJson("ok", "Reproducao interrompida.");
            }

            outStatusCode = 502;
            outStatusText = "Bad Gateway";
            return statusJson("error", response);
        }

        if ((method == "GET" || method == "POST") && path == "/delete")
        {
            int index = extractIndexFromPath(pathWithQuery);

            if (method == "POST" && index < 0)
            {
                std::regex indexRegex(R"("index"\s*:\s*(\d+))", std::regex::icase);
                std::smatch match;
                if (std::regex_search(body, match, indexRegex))
                {
                    index = std::stoi(match[1].str());
                }
            }

            if (index < 0)
            {
                outStatusCode = 400;
                outStatusText = "Bad Request";
                return statusJson("error", "Informe index via query (?index=) ou JSON {\"index\":N}.");
            }

            const std::string directDeleteResponse = sendSoundpadRequest("DoDeleteSound(" + std::to_string(index) + ")");
            if (directDeleteResponse.empty())
            {
                outStatusCode = 503;
                outStatusText = "Service Unavailable";
                return statusJson("error", "Soundpad offline.");
            }

            if (isRequestOk(directDeleteResponse))
            {
                return statusJson("ok", "Audio excluido com sucesso.");
            }

            // Fallback for versions without DoDeleteSound: select row then remove selected entry.
            const std::string selectResponse = sendSoundpadRequest("DoSelectIndex(" + std::to_string(index) + ")");
            if (selectResponse.empty())
            {
                outStatusCode = 503;
                outStatusText = "Service Unavailable";
                return statusJson("error", "Soundpad offline.");
            }

            if (!isRequestOk(selectResponse))
            {
                outStatusCode = 502;
                outStatusText = "Bad Gateway";
                return statusJson("error", selectResponse);
            }

            const std::string removeResponse = sendSoundpadRequest("DoRemoveSelectedEntries(false)");
            if (removeResponse.empty())
            {
                outStatusCode = 503;
                outStatusText = "Service Unavailable";
                return statusJson("error", "Soundpad offline.");
            }

            if (isRequestOk(removeResponse))
            {
                return statusJson("ok", "Audio excluido com sucesso.");
            }

            outStatusCode = 502;
            outStatusText = "Bad Gateway";
            return statusJson("error", removeResponse);
        }

        if (method == "POST" && path == "/upload")
        {
            std::string filename;
            std::string fileData;

            const auto contentType = findHeader(headers, "Content-Type").value_or("");
            const std::string contentTypeLower = toLower(contentType);

            if (contentTypeLower.find("multipart/form-data") != std::string::npos)
            {
                if (!parseMultipartFile(body, contentType, filename, fileData))
                {
                    outStatusCode = 400;
                    outStatusText = "Bad Request";
                    return statusJson("error", "Multipart invalido. Envie um campo de arquivo com filename.");
                }
            }
            else
            {
                filename = "uploaded_audio.bin";
                const size_t q = pathWithQuery.find("filename=");
                if (q != std::string::npos)
                {
                    filename = pathWithQuery.substr(q + 9);
                    const size_t amp = filename.find('&');
                    if (amp != std::string::npos)
                    {
                        filename = filename.substr(0, amp);
                    }
                    filename = trim(filename);
                }
                filename = std::filesystem::path(filename).filename().string();
                fileData = body;
            }

            if (filename.empty() || fileData.empty())
            {
                outStatusCode = 400;
                outStatusText = "Bad Request";
                return statusJson("error", "Arquivo nao informado ou vazio.");
            }

            const std::filesystem::path saveDir = getUploadDirectory();
            const std::filesystem::path savePath = saveDir / filename;

            std::ofstream output(savePath, std::ios::binary);
            if (!output.is_open())
            {
                outStatusCode = 500;
                outStatusText = "Internal Server Error";
                return statusJson("error", "Nao foi possivel salvar em appdata/Soundpad Deck.");
            }
            output.write(fileData.data(), static_cast<std::streamsize>(fileData.size()));
            output.close();

            // Register file in Soundpad list if possible.
            const std::string addCmd = "DoAddSound(\"" + savePath.string() + "\")";
            const std::string addResponse = sendSoundpadRequest(addCmd);

            std::ostringstream json;
            json << "{\"status\":\"ok\",\"message\":\"Upload salvo.\",\"savedPath\":\""
                 << jsonEscape(savePath.string()) << "\",\"size\":" << fileData.size()
                 << ",\"soundpadAdd\":\"" << jsonEscape(addResponse.empty() ? "offline" : addResponse) << "\"}";
            return json.str();
        }

        outKnownRoute = false;
        outStatusCode = 404;
        outStatusText = "Not Found";
        return statusJson("error", "Endpoint nao encontrado.");
    }

    bool recvAll(SOCKET socket, std::string &outBuffer, size_t minSize)
    {
        char temp[4096];
        while (outBuffer.size() < minSize)
        {
            const int readCount = recv(socket, temp, static_cast<int>(sizeof(temp)), 0);
            if (readCount <= 0)
            {
                return false;
            }
            outBuffer.append(temp, temp + readCount);
        }
        return true;
    }

    void handleClient(SOCKET client)
    {
        std::string request;

        if (!recvAll(client, request, 4))
        {
            closesocket(client);
            return;
        }

        const std::string separator = "\r\n\r\n";
        size_t headersEnd = request.find(separator);
        while (headersEnd == std::string::npos)
        {
            char temp[4096];
            const int readCount = recv(client, temp, static_cast<int>(sizeof(temp)), 0);
            if (readCount <= 0)
            {
                closesocket(client);
                return;
            }
            request.append(temp, temp + readCount);
            headersEnd = request.find(separator);
        }

        const std::string headerBlock = request.substr(0, headersEnd);
        const std::string bodyStart = request.substr(headersEnd + separator.size());

        std::istringstream headStream(headerBlock);
        std::string requestLine;
        std::getline(headStream, requestLine);
        if (!requestLine.empty() && requestLine.back() == '\r')
        {
            requestLine.pop_back();
        }

        std::istringstream requestLineStream(requestLine);
        std::string method;
        std::string path;
        std::string version;
        requestLineStream >> method >> path >> version;

        std::string headersRaw;
        std::string line;
        while (std::getline(headStream, line))
        {
            headersRaw += line;
            headersRaw += "\n";
        }
        const auto headers = parseHeaders(headersRaw);

        size_t contentLength = 0;
        if (const auto cl = findHeader(headers, "Content-Length"); cl.has_value())
        {
            try
            {
                contentLength = static_cast<size_t>(std::stoul(cl.value()));
            }
            catch (...)
            {
                contentLength = 0;
            }
        }

        std::string body = bodyStart;
        while (body.size() < contentLength)
        {
            char temp[4096];
            const int readCount = recv(client, temp, static_cast<int>(sizeof(temp)), 0);
            if (readCount <= 0)
            {
                break;
            }
            body.append(temp, temp + readCount);
        }

        bool knownRoute = false;
        int statusCode = 200;
        std::string statusText = "OK";
        std::string responseBody = handleApiRequest(method, path, headers, body, knownRoute, statusCode, statusText);

        const std::string response = httpResponse(responseBody, statusCode, statusText);
        send(client, response.data(), static_cast<int>(response.size()), 0);

        shutdown(client, SD_BOTH);
        closesocket(client);
    }

    void runApiServer()
    {
        WSADATA wsData;
        if (WSAStartup(MAKEWORD(2, 2), &wsData) != 0)
        {
            return;
        }

        SOCKET server = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if (server == INVALID_SOCKET)
        {
            WSACleanup();
            return;
        }

        sockaddr_in addr{};
        addr.sin_family = AF_INET;
        addr.sin_port = htons(API_PORT);
        addr.sin_addr.s_addr = htonl(INADDR_ANY);

        int opt = 1;
        setsockopt(server, SOL_SOCKET, SO_REUSEADDR, reinterpret_cast<const char *>(&opt), sizeof(opt));

        if (bind(server, reinterpret_cast<sockaddr *>(&addr), sizeof(addr)) == SOCKET_ERROR)
        {
            closesocket(server);
            WSACleanup();
            return;
        }

        if (listen(server, SOMAXCONN) == SOCKET_ERROR)
        {
            closesocket(server);
            WSACleanup();
            return;
        }

        while (g_running.load())
        {
            fd_set readSet;
            FD_ZERO(&readSet);
            FD_SET(server, &readSet);

            timeval timeout{};
            timeout.tv_sec = 1;
            timeout.tv_usec = 0;

            int ready = select(0, &readSet, nullptr, nullptr, &timeout);
            if (ready <= 0)
            {
                continue;
            }

            SOCKET client = accept(server, nullptr, nullptr);
            if (client == INVALID_SOCKET)
            {
                continue;
            }

            std::thread(handleClient, client).detach();
        }

        closesocket(server);
        WSACleanup();
    }

    LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
    {
        switch (msg)
        {
        case WM_COMMAND:
            if (LOWORD(wParam) == ID_TRAY_EXIT)
            {
                DestroyWindow(hwnd);
                return 0;
            }
            break;
        case WM_TRAYICON:
            if (lParam == WM_RBUTTONUP || lParam == WM_CONTEXTMENU)
            {
                POINT p;
                GetCursorPos(&p);

                HMENU menu = CreatePopupMenu();
                if (menu)
                {
                    InsertMenuW(menu, -1, MF_BYPOSITION, ID_TRAY_EXIT, L"Sair");
                    SetForegroundWindow(hwnd);
                    TrackPopupMenu(menu, TPM_BOTTOMALIGN | TPM_LEFTALIGN, p.x, p.y, 0, hwnd, nullptr);
                    DestroyMenu(menu);
                }
                return 0;
            }
            break;
        case WM_DESTROY:
        {
            NOTIFYICONDATAW nid{};
            nid.cbSize = sizeof(nid);
            nid.hWnd = hwnd;
            nid.uID = 1;
            Shell_NotifyIconW(NIM_DELETE, &nid);

            g_running.store(false);
            PostQuitMessage(0);
            return 0;
        }
        }

        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }

    bool createTrayIcon(HWND hwnd)
    {
        NOTIFYICONDATAW nid{};
        nid.cbSize = sizeof(nid);
        nid.hWnd = hwnd;
        nid.uID = 1;
        nid.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
        nid.uCallbackMessage = WM_TRAYICON;
        HICON appIcon = LoadIconW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_API_ICON));
        nid.hIcon = appIcon != nullptr ? appIcon : LoadIcon(nullptr, IDI_APPLICATION);
        lstrcpynW(nid.szTip, L"Soundpad Deck API (porta 1209)", ARRAYSIZE(nid.szTip));

        return Shell_NotifyIconW(NIM_ADD, &nid) == TRUE;
    }

} // namespace

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, PWSTR, int)
{
    const wchar_t CLASS_NAME[] = L"SoundpadDeckTrayWindow";

    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = CLASS_NAME;

    if (!RegisterClassExW(&wc))
    {
        return 1;
    }

    HWND hwnd = CreateWindowExW(
        0,
        CLASS_NAME,
        L"Soundpad Deck",
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        nullptr,
        nullptr,
        hInstance,
        nullptr);

    if (!hwnd)
    {
        return 1;
    }

    ShowWindow(hwnd, SW_HIDE);

    if (!createTrayIcon(hwnd))
    {
        DestroyWindow(hwnd);
        return 1;
    }

    std::thread apiThread(runApiServer);

    MSG msg;
    while (GetMessageW(&msg, nullptr, 0, 0) > 0)
    {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    if (apiThread.joinable())
    {
        apiThread.join();
    }

    disconnectPipe();
    return 0;
}