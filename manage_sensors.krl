ruleset io.picolabs.manage_sensors {
  meta {
    shares __testing, sensors, temperatures, get_all_temperatures
    use module io.picolabs.lesson_keys
    use module io.picolabs.sensor_profile alias profile
    use module io.picolabs.twilio_v2 alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscriptions
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ //{ "domain": "d1", "type": "t1" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    sensors = function(){
      ent:sensors.defaultsTo({})
    }
    temperatures = function(){
      ent:temperatures.defaultsTo({})
    }
    mischief = function(){
      ent:mischief.defaultsTo({})
    }
    things = function(){
      ent:things.defaultsTo({})
    }
    
    location = "SLC"
    threshold = 70
    number = "+18018089633"
    
    get_all_temperatures = function(){
      mysubscriptions = subscriptions:established("Tx_role", "sensor").klog("mysubscription");
      mysubscriptions.map(function(x){
        eci = x["Tx"].klog(Tx);
        url = "http://localhost:8080/sky/cloud/" + eci + "/io.picolabs.temperature_store/temperatures";
        {}.put(x["Tx_role"], http:get(url){"content"}.decode())
      });
    }
  }
  
  rule add_sensor{
    select when sensor new_sensor
    pre{
      name = event:attr("name")
      section_id = event:attr("section_id")
      sensor_contains = ent:sensors.filter(function(v,k){ name >< k })
    }
    if sensor_contains == {} then
      send_directive("valid_input", {"name": name, "section_id": section_id})
    fired{
      raise wrangler event "child_creation"
        attributes { "name":  name, "rids": ["io.picolabs.temperature_store", "io.picolabs.wovyn_base", "io.picolabs.sensor_profile", "io.picolabs.logging","io.picolabs.manage_sensors"], "section_id": section_id}
    }else{
      raise sensor event "duplicated_name"
        attributes{ "name": name }
    }
  }
  
  rule duplicated_name{
    select when sensor duplicated_name
      send_directive("duplicated_name", {"name": event:attr("name"), "sensors": ent:sensors})
  }
  
  rule store_new_section {
    select when wrangler child_initialized
    pre {
      the_section = {"name": event:attr("name"), "eci": event:attr("eci")}
      //section_id = event:attr("rs_attrs"){"section_id"}.klog("section_id")
      name = event:attr("name")
    }
    //if section_id.klog("found section_id") then
    event:send(
     { "eci": the_section{"eci"}, "eid": "update-profile",
       "domain": "sensor", "type": "profile_updated",
       "attrs": { 
                  "location" : location,
                  "name" : name,
                  "threshold" : threshold,
                  "number" : number
                 }
    });
      
    fired {
      raise wrangler event "subscription" attributes
       { "name" : the_section{"name"},
         "Rx_role": "manager",
         "Tx_role": "sensor",
         "channel_type": "subscription",
         "wellKnown_Tx" : the_section{"eci"}
       }
    }else{
      
    }
  }
  
  rule pending_subscription_added{
    select when wrangler subscription_added  
    pre{
      name = event:attr("name").klog("name")
      tx = event:attr("wellKnown_Tx").klog("tx")
    }
    
    fired{
      ent:sensors := ent:sensors.defaultsTo({});
      ent:sensors{[name]} := tx.klog("Section added");
    }
    else{
      
    }
  }
  
  rule unneeded_sensor {
    select when sensor unneeded_sensor
    pre{
      name_to_delete = event:attr("name").klog("name_to_delete")
      //sub_to_delete = subscriptions:wellKnown_Rx("name", name_to_delete).klog("sub_to_delete");
      //sub_to_delete_id = sub_to_delete{"policy_id"}.klog("sub_to_delete_id");
      exists = ent:sensors.filter(function(v,k){ name_to_delete >< k })
      new_sensors = ent:sensors.filter(function(v,k){ not(name_to_delete >< k) })
    }
    if exists != {} then
      send_directive("unneeded_sensor", {"name_to_delete": name_to_delete, "new_sensors": new_sensors, "exists": exists})
    fired{
      raise wrangler event "subscription_cancellation"
        attributes {"Tx": ent:sensors{[name_to_delete]}};
        
      raise wrangler event "child_deletion"
        attributes {"name": sub_to_delete};
      
      ent:sensors := new_sensors.klog("new_sensors");
    }
  }
  
  rule auto_accept {
  select when wrangler inbound_pending_subscription_added
  fired {
    raise wrangler event "pending_subscription_approval"
      attributes event:attrs
    }
  }
  
  rule get_all_temperatures{
    select when sensor temperatures
      foreach subscriptions.established().filter(funtion(x){x["Tx_role"] == "sensor"}) setting (s)
      pre{
        eci = s.klog("ECI")
        url = "http://localhost:8080/sky/cloud/" + eci + "/io.picolabs.temperature_store/temperatures"
      }
      fired{
        url_content = http:get(url){"content"}.decode().klog("URL_CONTENT");
        ent:temperatures := url_content;
       raise sensor event "get_temperatures"
      }else{
        
      }
  }

  rule mischief_who {
  select when mischief who
  pre {
      mischief = event:attr("eci")
      things = wrangler:children().map(function(v){v{"eci"}})
                                  .filter(function(v){v != mischief})
    }
    always {
      ent:mischief := mischief;
      ent:things := things
    }
  }
  
  rule mischief_subscriptions {
  select when mischief subscriptions
  foreach ent:things setting(thing,index)
    // introduce mischief pico to thing[index] pico
    event:send(
      { "eci": ent:mischief, "eid": "subscription",
        "domain": "wrangler", "type": "subscription",
        "attrs": { "name": "thing" + (index.as("Number")+1),
                   "Rx_role": "controller",
                   "Tx_role": "thing",
                   "channel_type": "subscription",
                   "wellKnown_Tx": thing } } )
  }
  
  rule threshold_notification {
    select when sensor notification
    pre{
      temperature = event:attr("temperature")
      timestamp = event:attr("timestamp")
      from = event:attr("from").klog("from")
      threshold = profile:threshold()
      to = profile:number().klog("to")
    }
    twilio:send_sms(to,
                    from,
                    "Temperature violation notification! Temperature was reported to be " + temperature + "°F." +
                    "The temperature threadshold is " + temperature_threshold + "°F. And this occured on the following time: " +
                    timestamp + ".")
  }


  rule get_temperature{
    select when sensor get_temperatures
      send_directive("Temperatures", {"temperatures": ent:temperatures})
  }
  
  
  rule clear_sensors  {
    select when sensor clear_sensors
      send_directive("clearing_sensors", {"result": "clearing sensors list"})
    fired{
       ent:sensors := {};
    }
  }
  rule clear_temperatures  {
    select when sensor clear_temperatures
      send_directive("clearing_temperatures", {"result": "clearing temperature list"})
    fired{
       ent:temperatures := {};
    }
  }
}
