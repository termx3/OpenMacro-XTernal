/************************************************************************
 * @description create embeds in a discordjs style
 * @file DiscordBuilder.ahk
 * @author ninju | .ninju.
 * @date 2024/03/20
 * @version 0.0.0
 ***********************************************************************/

Class EmbedBuilder {
   __New() {
      this.embedObj := {}
   }
   /**
    * @method setTitle()
    * @param {string} title 
    */
   setTitle(title) {
      if !(title is String)
         throw Error("expected a string", , title)
      this.embedObj.title := title
   }
   /**
    * @method setDescription()
    * @param {string} description 
    */
   setDescription(description) {
      if !(description is String)
         throw Error("expected a string", , description)
      this.embedObj.description := description
   }
   /**
    * @method setURL()
    * @param {URL} URL 
    */
   setURL(URL) {
      if !(URL is String)
         throw Error("expected a string", , URL)
      if !(RegExMatch(URL, ":\/\/"))
         throw Error("expected an URL", , URL)
      this.embedObj.url := URL
   }
   /**
    * @method setColor()
    * @param {Hex | Decimal Integer} Color 
    */
   setColor(Color) {
      if !(Color is Integer)
         throw Error("expected an integer", , Color)
      this.embedObj.color := Color + 0
   }
   /**
    * @method setTimestamp()
    * @param {timestamp} timestamp "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}"
    * @default this.now()
    */
   setTimeStamp(timestamp:="") {
      if IsSet(timestamp)
         if !RegExMatch(timestamp, "i)\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}")
            throw Error("invalid timestamp", , timestamp)
      time := A_NowUTC
      this.embedObj.timestamp := timestamp || SubStr(time, 1,4) "-" SubStr(time,5,2) "-" SubStr(time,7,2) "T" SubStr(time,9,2) ":" SubStr(time,11,2) ":" SubStr(time,13,2) ".000Z"
   }
   /**
    * @method setAuthor()
    * @param {object} author
    * @property {string} name
    * @property {url} url
    * @property {url} icon_url
    */
   setAuthor(author) {
      if !(author is object)
         throw Error("Expected an object literal")
      for k, v in author.OwnProps()
         if !this.hasVal(["name", "icon_url", "url"], k)
            throw Error("Expected one of the following propertires: `"name`", `"icon_url`", `"url`"`nReceived: " k)
      this.embedObj.author := author
   }
   /**
    * @method addFields()
    * @param {array of objects} fields .addFields([{name:"name",value:"value"}])
    * @property {string} name
    * @property {string} value
    * @property {Boolean} inline
    */
   addFields(fields) {
      if !(fields is Array)
         throw Error("expected an array", , fields)
      for i in fields {
         if !(i is Object)
            throw Error("Expected an object literal")
         for k, v in i.OwnProps()
            if !this.hasVal(["name", "value", "inline"], k)
               throw Error("Expected one of the following propertires: `"name`", `"value`", `"inline`"`nReceived: " k)
      }
      if this.embedObj.HasProp("fields")
         this.embedObj.fields.push(fields)
      else this.embedObj.fields := fields
   }
   /**
    * @method setFooter()
    * @param {object} footer
    * @property {string} text
    * @property {url} icon_url
    */
   setFooter(footer) {
      if !(footer is object)
         throw Error("Expected an object literal")
      for k, v in footer.OwnProps()
         if !this.hasVal(["text", "icon_url"], k)
            throw Error("Expected one of the following propertires: `"text`", `"icon_url`"`nReceived: " k)
      this.embedObj.footer := footer
   }
   /**
    * @method setThumbnail()
    * @param {object} thumbnail
    * @property {url} url
    */
   setThumbnail(thumbnail) {
      if !IsObject(thumbnail)
         throw Error("expected an object", , thumbnail)
      if !RegExMatch(thumbnail.url, ":\/\/")
         throw Error("requires an url or attachment.attachmentName (attachment://filename.extension)", , thumbnail.url)
      this.embedObj.thumbnail := thumbnail
   }
   hasVal(obj, val) {
      for k, v in obj
         if v = val
            return k
      return 0
   }
   /**
    * @method setImage()
    * @param {object} image
    * @property {url} url 
    */
   setImage(image) {
      if !IsObject(image)
         throw Error("expected an object", , image)
      if !RegExMatch(image.url, ":\/\/")
         throw Error("requires an url or attachment.attachmentName (attachment://filename.extension)", , image.url)
      this.embedObj.image := image
   }
}
Class AttachmentBuilder {
   /**
    * new AttachmentBuilder()
    * @param File relative path to file
    */
   __New(File) {
      if !FileExist(File)
         throw Error("Filename <" File "> doesnt exist", , File)
      this.fileName := File
      this.attachmentName := "attachment://" File
   }
}

Class Discord {
   Class Webhook extends Discord {
      __New(webhookURL) {
         if !RegexMatch(webhookURL, "^https?:\/\/discord\.com\/api\/webhooks\/\d+\/[\w|-]+$")
            throw Error("invalid webhook url")
         this.webhookURL := webhookURL
      }
   }
   send(obj) {
      for k, v in obj.embeds
         obj.embeds[k] := v.embedObj
      FileArr := []
      payload := '{"content":' (obj.HasProp("content") ? '"' obj.content '"' : "null") (obj.HasProp("embeds") ? ',"embeds":' this.dump(obj.embeds) : "") '}'
      objParam := { payload_json: payload, files: obj.files }
      this.createFormData(&payload, &header, objParam)
      wr := ComObject("WinHttp.WinHttpRequest.5.1")
      wr.Open("POST", this.webhookURL, true)
      wr.SetRequestHeader("Content-Type", header)
      wr.send(payload)
      wr.WaitForResponse
      if !this.response := wr.ResponseText
         return 1
      return 0
   }
   /**
    * @author tmplinshi | converted and edited by ninju
    * @url https://gist.github.com/tmplinshi/59618b75447e20f1f6402ba89b0e99cd
    * @param {string} retData the payload
    * @param {string} contentType returns the header
    * @param {object} fields input object
    */
   CreateFormData(&retData, &contentType, fields)
   {
      static chars := "0|1|2|3|4|5|6|7|8|9|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z"
      static CRLF := "`r`n"
      chars := Sort(chars, "D| Random")
      boundary := SubStr(StrReplace(chars, "|"), 1, 12)
      BoundaryLine := "------------------------------" . Boundary
      hData := DllCall("GlobalAlloc", "UInt", 0x2, "UPtr", 0, "Ptr")
      DllCall("ole32\CreateStreamOnHGlobal", "Ptr", hData, "Int", 0, "Ptr*", &pStream := 0, "UInt")

      len := 0, ptr := DllCall("GlobalAlloc", "UInt", 0x40, "UInt", 1, "Ptr")
      for k, v in fields.OwnProps() {
         If IsObject(v) {
            For i, file in v
            {
               str := BoundaryLine . CRLF
                  . 'Content-Disposition: form-data; name="' . file.fileName . '"; filename="' . file.fileName . '"' . CRLF
                  . "Content-Type: " . MimeType(file.fileName) . CRLF . CRLF
               StrPutUTF8(str, &ptr, &len)
               LoadFromFile(file.fileName, &ptr, &len)
               StrPutUTF8(CRLF, &ptr, &len)
            }
         } Else {
            str := BoundaryLine . CRLF
               . 'Content-Disposition: form-data; name="' . k '"' . CRLF . CRLF
               . v . CRLF
            StrPutUTF8(str, &ptr, &len)
         }
      }
      StrPutUTF8(str, &ptr, &len) {
         Local ReqSz := StrPut(str, "utf-8") - 1
         Len += ReqSz                                  ; GMEM_ZEROINIT|GMEM_MOVEABLE = 0x42
         Ptr := DllCall("GlobalReAlloc", "Ptr", Ptr, "UInt", len + 1, "UInt", 0x42)
         StrPut(str, Ptr + len - ReqSz, ReqSz, "utf-8")
      }

      LoadFromFile(Filename, &ptr, &len) {
         Local objFile := FileOpen(FileName, "r")
         Len += objFile.Length
         Ptr := DllCall("GlobalReAlloc", "Ptr", Ptr, "UInt", len, "UInt", 0x42)
         objFile.RawRead(Ptr + Len - objFile.length, objFile.length)
         objFile.Close()
      }
      MimeType(FileName) {
         i := FileOpen(FileName, "r")
         n := i.ReadUInt()
         Return (n = 0x474E5089) ? "image/png"
         : (n = 0x38464947) ? "image/gif"
            : (n & 0xFFFF = 0x4D42) ? "image/bmp"
               : (n & 0xFFFF = 0xD8FF) ? "image/jpeg"
                  : (n & 0xFFFF = 0x4949) ? "image/tiff"
                     : (n & 0xFFFF = 0x4D4D) ? "image/tiff"
                        : "application/octet-stream"
      }
      StrPutUTF8(BoundaryLine . "--" . CRLF, &ptr, &len)

      ; Create a bytearray and copy data in to it.
      retData := ComObjArray(0x11, Len) ; Create SAFEARRAY = VT_ARRAY|VT_UI1
      pvData := NumGet(ComObjValue(retData) + 8 + A_PtrSize, "uptr")
      DllCall("RtlMoveMemory", "Ptr", pvData, "Ptr", Ptr, "Ptr", Len)

      Ptr := DllCall("GlobalFree", "Ptr", Ptr, "Ptr")                   ; free global memory

      contentType := "multipart/form-data; boundary=----------------------------" . Boundary
   }
   dump(obj) {
      if !(obj is Object)
         return this.escapeStr(obj)
      out := ""
      if (obj is Array || obj is Map) {
         for k, v in obj {
            if (obj is Map)
               out .= this.escapeStr(k) ":"

            out .= this.dump(v) ","
         }

         if out != ""
            out := Trim(out, ",")

         return (obj is array) ? "[" . out . "]" : "{" . out . "}"
      }
      for k, v in obj.OwnProps() {
         out .= this.escapeStr(k) ":" this.dump(v) ","
      }
      if out != ""
         out := Trim(out, ",")
      return "{" out "}"
   }
   escapeStr(obj) => '"' StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(obj, "\", "\\"), "`t", "\t"), "`r", "\r"), "`n", "\n"), "`b", "\b"), "`f", "\f"), "/", "\/"), '"', '\"') '"'
}
;#Include <terminal>