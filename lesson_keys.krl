ruleset io.picolabs.lesson_keys {
   meta {
    key twilio {
          "account_sid": "AC88af0c8a49b43c37e144c322dc3ba55d", 
          "auth_token" : "f34147b41094fbb4cbf9c9c40475f240"
    }
    provides keys twilio to io.picolabs.use_twilio_v2
    provides keys twilio to io.picolabs.wovyn_base
    provides keys twilio to io.picolabs.manage_sensors
  }
}
