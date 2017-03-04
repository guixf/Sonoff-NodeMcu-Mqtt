local dispatcher = {}

function sendData()
		if (GPIO_LED ~= GPIO_BL_LED) then gpio.write(GPIO_BL_LED,gpio.LOW) end
	local temp, humi,stat = getTempHumi()
		if (stat == dht.OK ) then
			tempjson="{\"temperature\":\""..temp.."\",\"humidity\":\""..humi.."\"}"
			print("send .." .. tempjson)
			m:publish(MQTT_MAINTOPIC .."/sensor",tempjson,0,0)
		end
		if (GPIO_LED ~= GPIO_BL_LED) then gpio.write(GPIO_BL_LED,gpio.HIGH) end
end

function getTempHumi()
  local status,temp,humi,temp_decimial,humi_decimial = dht.read(GPIO_DHT)
  if( status == dht.OK ) then
    -- Float firmware using this example

  elseif( status == dht.ERROR_CHECKSUM ) then
    print( "DHT Checksum error." );
  elseif( status == dht.ERROR_TIMEOUT ) then
    print( "DHT Time out." );
  end
  return temp, humi,status
end


-- client activation
m = mqtt.Client(MQTT_CLIENTID, 60, MQTT_USERNAME,MQTT_PASSWORD) -- no pass !

-- actions
function switch_power(m, pl)
	if pl == "on" then
		gpio.write(GPIO_SWITCH, gpio.HIGH)
		gpio.write(GPIO_LED,gpio.LOW)
		m:publish(MQTT_MAINTOPIC.."/stat","ON",0,0)
		print("MQTT : plug ON for ", MQTT_CLIENTID)
	elseif( pl == "off") then 
		gpio.write(GPIO_SWITCH, gpio.LOW)
		gpio.write(GPIO_LED,gpio.HIGH)
		m:publish(MQTT_MAINTOPIC.."/stat","OFF",0,0)
		print("MQTT : plug OFF for ", MQTT_CLIENTID)
	elseif( pl == "?" ) then  --返回状态
		if(gpio.read(GPIO_SWITCH) == 0) then
			m:publish(MQTT_MAINTOPIC.."/stat","ON",0,0)
			else
			m:publish(MQTT_MAINTOPIC.."/stat","OFF",0,0)
		end
	end
end


-- events
m:lwt('/lwt', MQTT_CLIENTID .. " died !", 0, 0)

m:on('connect', function(m)
	print('MQTT : ' .. MQTT_CLIENTID .. " connected to : " .. MQTT_HOST .. " on port : " .. MQTT_PORT)
	MQTTReady = 1
	m:subscribe(MQTT_MAINTOPIC..'/', 0, function (m)
		print('MQTT : subscribed to ', MQTT_MAINTOPIC) 
		--if GPIO_DHT~=nil then 
			tmr.alarm(3,5000,1,sendData)
		--end
	end)
	gpio.trig(GPIO_BUTTON, "up", M_button_press )
end)

m:on('offline', function(m)
	MQTTReady = 0
    ip = wifi.sta.getip()
    print ("MQTT reconnecting to " .. mqttBroker .. " from " .. ip)
    tmr.alarm(3, 10000, 0, function()
        --node.restart();
		--blinking({1000,2000}) 
    end)
end)

m:on('message', function(m, topic, pl)
	print('MQTT : Topic ', topic, ' with payload ', pl)
		switch_power(m,pl)

end)



-- Start
gpio.mode(GPIO_SWITCH, gpio.OUTPUT)
gpio.mode(GPIO_LED, gpio.OUTPUT)
gpio.mode(GPIO_BL_LED, gpio.OUTPUT)
dispatcher[MQTT_MAINTOPIC] = switch_power
m:connect(MQTT_HOST, MQTT_PORT, 0, 1)
