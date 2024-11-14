# coffeelint: disable=max_line_length
module.exports = ->
  schemaVersion: 2
  "-enableQuickSwitch": false
  "-refreshOnProfileChange": true
  "-startupProfileName": ""
  "-quickSwitchProfiles": []
  "-revertProxyChanges": true
  "-confirmDeletion": true
  "-showInspectMenu": true
  "-addConditionsToBottom": false
  "-showExternalProfile": true
  "-downloadInterval": 60
  "+proxy":
    bypassList: [
      {
        pattern: "127.0.0.1"
        conditionType: "BypassCondition"
      }
      {
        pattern: "::1"
        conditionType: "BypassCondition"
      }
      {
        pattern: "localhost"
        conditionType: "BypassCondition"
      }
    ]
    profileType: "FixedProfile"
    name: "proxy"
    color: "#99ccee"
    fallbackProxy:
      port: 8080
      scheme: "http"
      host: "proxy.example.com"
  "+__ruleListOf_auto switch":
    name: "__ruleListOf_auto switch",
    defaultProfileName: "direct",
    profileType: "RuleListProfile",
    color: "#99dd99",
    format: "Switchy",
    matchProfileName: "proxy",
    ruleList: "[SwitchyOmega Conditions]\n; Require: SwitchyOmega >= 2.3.2\n; By Node-x\n\n*.kekkai.io\n*.getgrass.io\n*,getgrass.io\n*.bigdatacloud.net\n*.wynd.network\n*.clarity.ms\n*.gradient.network\nclarity.ms\n*.blockmesh.xyz",
    sourceUrl: "https://raw.githubusercontent.com/cnsilvan/node-x/refs/heads/main/depin/proxy_rules.txt",
    lastUpdate: "2024-11-12T09:47:45.671Z"
  "+auto switch":
    profileType: "SwitchProfile"
    rules: []
    name: "auto switch"
    color: "#99dd99"
    defaultProfileName: "__ruleListOf_auto switch"



