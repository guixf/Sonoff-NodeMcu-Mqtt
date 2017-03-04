if (net_ready == nil) then
	print("Start WEB Config.")
	if (m ~= nil) then m:close() end
	if (WIFISETUP_ID == nil) then WIFISETUP_ID = 3 end
	print("Setting up Wifi AP.."..node.heap())
	wifi.setmode(wifi.SOFTAP)
	id =  tostring(node.chipid())
	wifi.ap.config({ssid="ESP8266_"..id})  
	wifi.ap.setip({ip="192.168.4.1",netmask="255.255.255.0",gateway="192.168.4.1"})
		collectgarbage()    
		tmr.alarm(WIFISETUP_ID,5000,1, function() 
			if (wifi.ap.getip() ~= nil ) then 
				setup_server() 
			end
		end )
--setup_server() 
end

local unescape = function (s)
   s = string.gsub(s, "+", " ")
   s = string.gsub(s, "%%(%x%x)", function (h)
         return string.char(tonumber(h, 16))
      end)
   return s
end

function BP()
    local key = gpio.read(GPIO_BUTTON)
    if (key == 0) then
        keyCnt = keyCnt + 1
    else
        if(keyCnt > 1 ) then
			node.restart()
        end
    end
end

function setup_server()

   print("Setting up webserver. mem = "..node.heap())		
--web server
srv = nil
   srv=net.createServer(net.TCP)
   net_ready = 1
   srv:listen(80,function(conn)
       conn:on("receive", function(client,request)
           local buf = ""
           local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP");
           if(method == nil)then
               _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP")
           end
           local _GET = {}
           if (vars ~= nil)then
               for k, v in string.gmatch(vars, "(%w+)=([^%&]+)&*") do
                   _GET[k] = unescape(v)
					-- print(k..' : '.._GET[k])
               end
           end
           --print(string.gsub(_GET.mqtttopic,'/','//'))
           if (_GET.psw ~= nil and _GET.ap ~= nil  ) then
			  tmr.alarm(6, 100, tmr.ALARM_AUTO) --not INTERRUPT
			
              client:send("Saving data..")
              file.open("config.lua", "w")
              file.writeline('-- WIFI --')
              file.writeline('WIFI_SSID = "' .. _GET.ap .. '"')
              file.writeline('WIFI_PASS = "' .. _GET.psw .. '"')
              file.writeline('-- MQTT --')
              file.writeline('MQTT_HOST = "' .. _GET.mqtthost .. '"')
              file.writeline('MQTT_PORT = "' .. _GET.mqttport .. '"')
              file.writeline('MQTT_MAINTOPIC = "' .. _GET.mqtttopic .. '"')
              file.writeline('MQTT_CLIENTID = "'.. _GET.mqttclientid.. '"')
              file.writeline('MQTT_USERNAME = "' .. _GET.mqttuser .. '"')
              file.writeline('MQTT_PASSWORD = "' .. _GET.mqttpasswd .. '"')
              file.writeline('-- WIFI_SETTING_END --')
			
              file.close()
              collectgarbage()              
              node.compile("config.lua")
              node.restart()
           end


		   buf = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n<!DOCTYPE HTML>\r\n<html><body>"
           buf = buf .. "<h3>Configure WiFi</h3><br>"
           buf = buf .. "<form method='get' action='http://"..wifi.ap.getip().."'>"
           buf = buf .. "wifi SSID: <input type='text' name='ap' value='"..WIFI_SSID.."'></input><br>"
           buf = buf .. "wifi password: <input type='password' name='psw' value='"..WIFI_PASS.."'></input><br>"
           buf = buf .. "<h3>Configure MQTT</h3><br>"
           buf = buf .. "mqtt_host: <input type='text' name='mqtthost'  value='"..MQTT_HOST.."'></input><br>"
           buf = buf .. "wifi mqtt_port: <input type='text' name='mqttport'  value='"..MQTT_PORT.."'></input><br>"
           buf = buf .. "mqtt Topic: <input type='text' name='mqtttopic' value='"..MQTT_MAINTOPIC.."'></input><br>"
           buf = buf .. "mqtt chipid: <input type='text' name='mqttclientid' value='"
		   buf = buf..MQTT_CLIENTID
		   if (MQTT_USERNAME ~= "") then 
				buf = buf .. "'></input><br>mqtt user: <input type='text' name='mqttuser' value='"..MQTT_USERNAME.."'></input><br>"
           else
				buf = buf .. "'></input><br>mqtt user: <input type='text' name='mqttuser'></input><br>"
           end
           if (MQTT_PASSWORD ~= "") then
				buf = buf .. "mqtt password: <input type='text' name='mqttpasswd' value='"..MQTT_PASSWORD.."'></input><br>"
           else
				buf = buf .. "mqtt password: <input type='text' name='mqttpasswd'></input><br>"
           end
           buf = buf .. "<br><button type='submit'>保存</button>"
           buf = buf .. "</form></body></html>"
           client:send(buf)
           client:close()
           collectgarbage()
       end)
   end)
   
   print("Please connect to: " .. wifi.ap.getip())
   tmr.stop(WIFISETUP_ID)
		tmr.alarm(6, 100, tmr.ALARM_AUTO, BP)
end

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end
