-- init all globals

function load_lib(fname)
    if file.open(fname .. ".lc") then
        file.close()
        dofile(fname .. ".lc")
    else
        dofile(fname .. ".lua")
    end
end

load_lib("config")
load_lib("config_hard")

local wifiReady = 0
local net_ready = 0
local firstPass = 0
MQTTReady = 0
keyCnt = 0
ledOn = false

    gpio.mode(GPIO_LED, gpio.OUTPUT)
    gpio.mode(GPIO_BL_LED, gpio.OUTPUT)
    gpio.mode(GPIO_SWITCH, gpio.OUTPUT)
	gpio.mode(GPIO_BUTTON, gpio.INPUT, gpio.PULLUP)
	   
   
function configureWiFi()
	tmr.alarm(6, 100, tmr.ALARM_AUTO, button_press)
    wifi.setmode(wifi.STATION)
    wifi.sta.config(WIFI_SSID, WIFI_PASS)
	--wifi.sta.autoconnect(1)
	 blinking({2000, 2000})  --未找到AP
   tmr.alarm(WIFI_ALARM_ID, 2000, 1, wifi_watch)
end

function wifi_watch() 
    status = wifi.sta.status()
    -- only do something if the status actually changed (5: STATION_GOT_IP.)
    if status == 5 and wifiReady == 0 then
    		    blinking({100,10000}) --闪动，亮100，息1000
                wifiReady = 1
                print("WiFi: connected with " .. wifi.sta.getip())
        		print("Start Mqtt connect.")
        		load_lib("broker")
    elseif status == 5 and wifiReady == 1 then
        if firstPass == 0 then
            --load_lib("ota")
            --firstPass = 1
           -- tmr.stop(WIFI_LED_BLINK_ALARM_ID)
            --turnWiFiLedOn()
        end
    elseif status == 3 then
		blinking({2000, 2000})  --未找到AP
	elseif status == 2 then
	    blinking({100, 100 , 100, 500})  --错误密码
	elseif status == 1 then
	    blinking({300, 300}) --正在连接
	elseif status ==255 then
	
	else
	      wifiReady = 0
	      blinking({2000, 2000})  --未找到AP
        print("WiFi: (re-)connecting")
    end
end

function blinking(param)
    if type(param) == 'table' then
        blink = param
        blink.i = 0
        tmr.interval(WIFI_LED_BLINK_ALARM_ID, 1)
        running, _ = tmr.state(WIFI_LED_BLINK_ALARM_ID)
        if running ~= true then
            tmr.start(WIFI_LED_BLINK_ALARM_ID)
        end
    else
        tmr.stop(WIFI_LED_BLINK_ALARM_ID)
        gpio.write(GPIO_BL_LED, param or gpio.LOW)
    end
end

function button_press()
    local key = gpio.read(GPIO_BUTTON)
    if (key == 0) then
        keyCnt = keyCnt + 1
    else
        if(keyCnt > 50 ) then
        print("Long Press!")
			if(gpio.read(GPIO_LED) == 0 ) then
				blinking({500, 500}) 
				file.open("setup", "w")
				file.writeline('-- WIFISETUP --')
				file.close()
				node.restart()
			else
				blinking({1000, 500})
				node.restart()
			end
			keyCnt = 0
		elseif(keyCnt > 1) then
            SwitchCtrl()
            keyCnt = 0
        end
    end

end
	
function SwitchCtrl()
	    if(gpio.read(GPIO_LED) == 0 )then
			gpio.write(GPIO_LED, gpio.HIGH)
			gpio.write(GPIO_SWITCH,gpio.LOW)
			--print(MQTTReady)
			if (MQTTReady == 1) then 
					m:publish(MQTT_MAINTOPIC.."/stat","OFF",0,0)
			end
			print("button turn to OFF")
        else
			gpio.write(GPIO_LED,gpio.LOW)
			gpio.write(GPIO_SWITCH,gpio.HIGH)
			if (MQTTReady == 1) then 
					m:publish(MQTT_MAINTOPIC.."/stat","ON",0,0)
			end			
			print("button turn to ON")
        end
end


-- Configure
blink = nil
tmr.register(WIFI_LED_BLINK_ALARM_ID, 100, tmr.ALARM_AUTO, function()
    gpio.write(GPIO_BL_LED, blink.i % 2)
    tmr.interval(WIFI_LED_BLINK_ALARM_ID, blink[blink.i + 1])
    blink.i = (blink.i + 1) % #blink
end)


if (file.open("setup")) then
   file.close()
   file.remove("setup")
     blinking({100, 100})
	 load_lib("wifi_setup")
else
configureWiFi()
end

