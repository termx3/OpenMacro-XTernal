#Requires AutoHotkey v2.0
#SingleInstance Force

class Api {
    __New() {
        this.Routes := Map()
        this.GlobalGuards := []
        this.ListenSocket := 0
        this.IsRunning := false
        this._onExitHandler := ObjBindMethod(this, "Shutdown")
    }

    Get(path, handler) {
        return this.Route("GET", path, handler)
    }

    Post(path, handler) {
        return this.Route("POST", path, handler)
    }

    Put(path, handler) {
        return this.Route("PUT", path, handler)
    }

    Delete(path, handler) {
        return this.Route("DELETE", path, handler)
    }

    Route(method, path, handler) {
        method := StrUpper(Trim(method))
        path := this.NormalizePath(path)

        if !HasMethod(handler, "Call")
            throw TypeError("handler must be callable.")

        key := method " " path
        route := RouteDef(method, path, handler)
        this.Routes[key] := route
        return route
    }

    Require(guard) {
        if !HasMethod(guard, "Call")
            throw TypeError("guard must be callable.")
        this.GlobalGuards.Push(guard)
        return this
    }

    Run(port := 8080) {
        if this.IsRunning
            throw Error("Server is already running.")

        wsadata := Buffer(408, 0)
        if DllCall("ws2_32\WSAStartup", "UShort", 0x0202, "Ptr", wsadata.Ptr, "Int")
            throw Error("WSAStartup failed: " this.WSAError())

        this.ListenSocket := DllCall("ws2_32\socket", "Int", 2, "Int", 1, "Int", 6, "Ptr")
        if (this.ListenSocket = -1)
            throw Error("socket failed: " this.WSAError())

        reuse := Buffer(4, 0)
        NumPut("Int", 1, reuse, 0)
        DllCall("ws2_32\setsockopt"
            , "Ptr", this.ListenSocket
            , "Int", 0xFFFF
            , "Int", 4
            , "Ptr", reuse.Ptr
            , "Int", reuse.Size
            , "Int")

        addr := Buffer(16, 0)
        NumPut("UShort", 2, addr, 0)
        NumPut("UShort", DllCall("ws2_32\htons", "UShort", port, "UShort"), addr, 2)
        NumPut("UInt", 0, addr, 4)

        if DllCall("ws2_32\bind", "Ptr", this.ListenSocket, "Ptr", addr.Ptr, "Int", addr.Size, "Int")
            throw Error("bind failed: " this.WSAError())

        if DllCall("ws2_32\listen", "Ptr", this.ListenSocket, "Int", 32, "Int")
            throw Error("listen failed: " this.WSAError())

        this.IsRunning := true
        OnExit(this._onExitHandler)

        while this.IsRunning {
            client := DllCall("ws2_32\accept", "Ptr", this.ListenSocket, "Ptr", 0, "Ptr", 0, "Ptr")
            if (client = -1) {
                if this.IsRunning
                    continue
                break
            }
            this.HandleClient(client)
        }
    }

    Shutdown(*) {
        this.IsRunning := false

        if this.ListenSocket {
            DllCall("ws2_32\closesocket", "Ptr", this.ListenSocket, "Int")
            this.ListenSocket := 0
        }

        DllCall("ws2_32\WSACleanup", "Int")
    }

    HandleClient(client) {
        try {
            raw := this.ReadRawRequest(client)
            if (raw = "") {
                this.CloseClient(client)
                return
            }

            req := this.ParseRequest(raw)
            resp := this.Dispatch(req)
            this.SendResponse(client, resp)
        } catch as err {
            try this.SendResponse(client, Response.Text("Internal Server Error", 500))
        } finally {
            this.CloseClient(client)
        }
    }

    ReadRawRequest(client) {
        raw := ""
        chunk := Buffer(8192, 0)
        headerEndPos := 0
        contentLength := 0

        loop {
            bytesRead := DllCall("ws2_32\recv", "Ptr", client, "Ptr", chunk.Ptr, "Int", chunk.Size, "Int", 0, "Int")
            if (bytesRead <= 0)
                break

            raw .= StrGet(chunk.Ptr, bytesRead, "CP0")

            if !headerEndPos {
                headerEndPos := InStr(raw, "`r`n`r`n")
                if headerEndPos {
                    headersText := SubStr(raw, 1, headerEndPos - 1)
                    contentLength := this.ExtractContentLength(headersText)
                    if (contentLength = 0)
                        break
                }
            }

            if headerEndPos {
                body := SubStr(raw, headerEndPos + 4)
                if (StrLen(body) >= contentLength)
                    break
            }
        }

        return raw
    }

    ParseRequest(raw) {
        headerEndPos := InStr(raw, "`r`n`r`n")
        if !headerEndPos
            throw Error("Malformed HTTP request.")

        head := SubStr(raw, 1, headerEndPos - 1)
        body := SubStr(raw, headerEndPos + 4)
        lines := StrSplit(head, "`r`n")

        if (lines.Length < 1)
            throw Error("Missing request line.")

        requestLine := lines[1]
        parts := StrSplit(requestLine, " ")

        if (parts.Length < 2)
            throw Error("Malformed request line.")

        method := StrUpper(parts[1])
        rawPath := parts[2]

        qPos := InStr(rawPath, "?")
        if qPos {
            path := SubStr(rawPath, 1, qPos - 1)
            queryString := SubStr(rawPath, qPos + 1)
        } else {
            path := rawPath
            queryString := ""
        }

        path := this.NormalizePath(path)
        headers := Map()

        Loop lines.Length - 1 {
            line := lines[A_Index + 1]
            if (line = "")
                continue

            colonPos := InStr(line, ":")
            if !colonPos
                continue

            name := Trim(SubStr(line, 1, colonPos - 1))
            value := Trim(SubStr(line, colonPos + 1))
            headers[name] := value
        }

        return Request(method, path, rawPath, this.ParseQuery(queryString), headers, body, raw)
    }

    ParseQuery(queryString) {
        query := Map()

        if (queryString = "")
            return query

        for _, pair in StrSplit(queryString, "&") {
            if (pair = "")
                continue

            eqPos := InStr(pair, "=")
            if eqPos {
                key := this.UrlDecode(SubStr(pair, 1, eqPos - 1))
                value := this.UrlDecode(SubStr(pair, eqPos + 1))
            } else {
                key := this.UrlDecode(pair)
                value := ""
            }

            query[key] := value
        }

        return query
    }

    UrlDecode(value) {
        value := StrReplace(value, "+", " ")
        out := ""
        i := 1

        while (i <= StrLen(value)) {
            ch := SubStr(value, i, 1)

            if (ch = "%" && i + 2 <= StrLen(value)) {
                hex := SubStr(value, i + 1, 2)
                if RegExMatch(hex, "^[0-9A-Fa-f]{2}$") {
                    out .= Chr("0x" hex)
                    i += 3
                    continue
                }
            }

            out .= ch
            i += 1
        }

        return out
    }

    Dispatch(req) {
        key := req.Method " " req.Path

        if !this.Routes.Has(key)
            return Response.Text("Not Found", 404)

        route := this.Routes[key]

        guardResp := this.RunGuards(this.GlobalGuards, req)
        if (guardResp != "")
            return guardResp

        guardResp := this.RunGuards(route.Guards, req)
        if (guardResp != "")
            return guardResp

        result := route.Handler.Call(req)
        return this.NormalizeResponse(result)
    }

    RunGuards(guards, req) {
        for _, guard in guards {
            result := guard.Call(req)
            if (result == 1)
                continue
            return this.NormalizeResponse(result)
        }
        return ""
    }

    NormalizeResponse(result) {
        if (result is Response)
            return result

        typeName := Type(result)

        if (typeName = "Map" || typeName = "Array")
            return Response.Json(result)

        if IsObject(result)
            return Response.Json(this.ObjectToMap(result))

        return Response.Text(result "")
    }

    ObjectToMap(obj) {
        mapObj := Map()
        for name, value in obj.OwnProps()
            mapObj[name] := value
        return mapObj
    }

    SendResponse(client, resp) {
        raw := this.BuildRawResponse(resp)
        bytesNeeded := StrPut(raw, "UTF-8")
        buf := Buffer(bytesNeeded, 0)
        bytesWritten := StrPut(raw, buf, "UTF-8") - 1

        sentTotal := 0
        while (sentTotal < bytesWritten) {
            sent := DllCall("ws2_32\send"
                , "Ptr", client
                , "Ptr", buf.Ptr + sentTotal
                , "Int", bytesWritten - sentTotal
                , "Int", 0
                , "Int")

            if (sent <= 0)
                break

            sentTotal += sent
        }
    }

    BuildRawResponse(resp) {
        headers := Map()
        for name, value in resp.Headers
            headers[name] := value

        body := resp.Body ""

        if !headers.Has("Content-Type")
            headers["Content-Type"] := "text/plain; charset=utf-8"

        if !headers.Has("Connection")
            headers["Connection"] := "close"

        headers["Content-Length"] := this.Utf8ByteLen(body)

        statusLine := "HTTP/1.1 " resp.StatusCode " " this.StatusText(resp.StatusCode) "`r`n"
        headerLines := ""

        for name, value in headers
            headerLines .= name ": " value "`r`n"

        return statusLine headerLines "`r`n" body
    }

    Utf8ByteLen(text) {
        return StrPut(text, "UTF-8") - 1
    }

    ExtractContentLength(headersText) {
        if RegExMatch(headersText, "im)^Content-Length:\s*(\d+)\s*$", &m)
            return m[1] + 0
        return 0
    }

    NormalizePath(path) {
        path := Trim(path)
        if (path = "")
            return "/"
        if (SubStr(path, 1, 1) != "/")
            path := "/" path
        return path
    }

    StatusText(statusCode) {
        static texts := Map(
            100, "Continue",
            101, "Switching Protocols",
            102, "Processing",
            103, "Early Hints",
            104, "Upload Resumption Supported",

            200, "OK",
            201, "Created",
            202, "Accepted",
            203, "Non-Authoritative Information",
            204, "No Content",
            205, "Reset Content",
            206, "Partial Content",
            207, "Multi-Status",
            208, "Already Reported",
            226, "IM Used",

            300, "Multiple Choices",
            301, "Moved Permanently",
            302, "Found",
            303, "See Other",
            304, "Not Modified",
            305, "Use Proxy",
            306, "(Unused)",
            307, "Temporary Redirect",
            308, "Permanent Redirect",

            400, "Bad Request",
            401, "Unauthorized",
            402, "Payment Required",
            403, "Forbidden",
            404, "Not Found",
            405, "Method Not Allowed",
            406, "Not Acceptable",
            407, "Proxy Authentication Required",
            408, "Request Timeout",
            409, "Conflict",
            410, "Gone",
            411, "Length Required",
            412, "Precondition Failed",
            413, "Content Too Large",
            414, "URI Too Long",
            415, "Unsupported Media Type",
            416, "Range Not Satisfiable",
            417, "Expectation Failed",
            418, "(Unused)",
            421, "Misdirected Request",
            422, "Unprocessable Content",
            423, "Locked",
            424, "Failed Dependency",
            425, "Too Early",
            426, "Upgrade Required",
            428, "Precondition Required",
            429, "Too Many Requests",
            431, "Request Header Fields Too Large",
            451, "Unavailable For Legal Reasons",

            500, "Internal Server Error",
            501, "Not Implemented",
            502, "Bad Gateway",
            503, "Service Unavailable",
            504, "Gateway Timeout",
            505, "HTTP Version Not Supported",
            506, "Variant Also Negotiates",
            507, "Insufficient Storage",
            508, "Loop Detected",
            510, "Not Extended",
            511, "Network Authentication Required"
        )

        return texts.Has(statusCode) ? texts[statusCode] : "OK"
    }

    CloseClient(client) {
        DllCall("ws2_32\closesocket", "Ptr", client, "Int")
    }

    WSAError() {
        return DllCall("ws2_32\WSAGetLastError", "Int")
    }

    static Text(body, statusCode := 200) {
        return Response.Text(body, statusCode)
    }

    static Json(value, statusCode := 200) {
        return Response.Json(value, statusCode)
    }
}

class RouteDef {
    __New(method, path, handler) {
        this.Method := method
        this.Path := path
        this.Handler := handler
        this.Guards := []
    }

    Require(guard) {
        if !HasMethod(guard, "Call")
            throw TypeError("guard must be callable.")
        this.Guards.Push(guard)
        return this
    }
}

class Request {
    __New(method, path, rawPath, query, headers, body, raw) {
        this.Method := method
        this.Path := path
        this.RawPath := rawPath
        this.Query := query
        this.Headers := headers
        this.Body := body
        this.Raw := raw
    }

    Header(name, default := "") {
        needle := StrLower(name)
        for key, value in this.Headers {
            if (StrLower(key) = needle)
                return value
        }
        return default
    }

    Text() {
        return this.Body
    }
}

class Response {
    __New(body := "", statusCode := 200, headers := "") {
        this.Body := body ""
        this.StatusCode := statusCode
        this.Headers := headers is Map ? headers : Map()
    }

    static Text(body, statusCode := 200, headers := "") {
        hdrs := Response.CloneHeaders(headers)
        hdrs["Content-Type"] := "text/plain; charset=utf-8"
        return Response(body "", statusCode, hdrs)
    }

    static Html(body, statusCode := 200, headers := "") {
        hdrs := Response.CloneHeaders(headers)
        hdrs["Content-Type"] := "text/html; charset=utf-8"
        return Response(body "", statusCode, hdrs)
    }

    static Json(value, statusCode := 200, headers := "") {
        hdrs := Response.CloneHeaders(headers)
        hdrs["Content-Type"] := "application/json; charset=utf-8"
        return Response(Json.Dump(value), statusCode, hdrs)
    }

    static NoContent() {
        return Response("", 204, Map())
    }

    static CloneHeaders(headers) {
        out := Map()
        if (headers is Map) {
            for name, value in headers
                out[name] := value
        }
        return out
    }
}

class Json {
    static Dump(value) {
        return Json._Dump(value)
    }

    static _Dump(value) {
        typeName := Type(value)

        switch typeName {
            case "String":
                return '"' Json.Escape(value) '"'
            case "Integer", "Float":
                return value ""
            case "Map":
                return Json.DumpMap(value)
            case "Array":
                return Json.DumpArray(value)
            default:
                if IsObject(value)
                    return Json.DumpObject(value)
                return '"' Json.Escape(value "") '"'
        }
    }

    static DumpMap(mapObj) {
        out := "{"
        first := true

        for key, value in mapObj {
            if !first
                out .= ","
            first := false
            out .= '"' Json.Escape(key "") '":' Json._Dump(value)
        }

        return out "}"
    }

    static DumpArray(arr) {
        out := "["
        first := true

        for _, value in arr {
            if !first
                out .= ","
            first := false
            out .= Json._Dump(value)
        }

        return out "]"
    }

    static DumpObject(obj) {
        out := "{"
        first := true

        for name, value in obj.OwnProps() {
            if !first
                out .= ","
            first := false
            out .= '"' Json.Escape(name) '":' Json._Dump(value)
        }

        return out "}"
    }

    static Escape(text) {
        text := StrReplace(text, "\", "\\")
        text := StrReplace(text, '"', '\"')
        text := StrReplace(text, "`r", "\r")
        text := StrReplace(text, "`n", "\n")
        text := StrReplace(text, "`t", "\t")
        return text
    }
}



app := Api()

app.Get("/test", TestOk)

app.Get("/private", PrivateData)
    .Require(ApiKeyGuard)

app.Run(8080)



TestOk(req) {
    return "ok"
}

PrivateData(req) {
    return Map(
        "secret", "granted",
        "path", req.Path
    )
}

ApiKeyGuard(req) {
    if (req.Header("X-API-Key") = "secret")
        return true

    return Response.Json(Map(
        "error", "unauthorized"
    ), 401)
}