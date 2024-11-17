OmegaTarget = require('omega-target')
# coffeelint: disable=max_line_length
Promise = OmegaTarget.Promise
ProxyAuth = require('./proxy_auth')
CryptoJS = require 'crypto-js'
class ProxyImpl
  constructor: (log) ->
    @log = log

  @isSupported: -> false

  applyProfile: (profile, meta) ->
    Promise.reject()

  watchProxyChange: (callback) ->
    null

  parseExternalProfile: (details, options) ->
    null

  _profileNotFound: (name) =>
    @log.error("Profile #{name} not found! Things may go very, very wrong.")
    return OmegaPac.Profiles.create({
      name: name
      profileType: 'VirtualProfile'
      defaultProfileName: 'direct'
    })

  decryptProxy = (encryptedProxyBase64, aesKey) ->
# 检查 AES 密钥是否存在且长度为 32 字节
    throw new Error('AES key must be 32 bytes long.') unless aesKey and aesKey.length is 32
  # Base64 解码
    encryptedBytes = CryptoJS.enc.Base64.parse encryptedProxyBase64
  # 将 AES 密钥转换为 UTF-8 格式
    aesKeyUtf8 = CryptoJS.enc.Utf8.parse aesKey
  # 解密操作
    decrypted = CryptoJS.AES.decrypt(
     { ciphertext: encryptedBytes },  # 密文
     aesKeyUtf8,                      # AES 密钥
     mode: CryptoJS.mode.ECB,         # 加密模式为 ECB
     padding: CryptoJS.pad.Pkcs7      # 填充方式为 PKCS#7
    )
   # 返回解密后的字符串
    decrypted.toString CryptoJS.enc.Utf8

  getDecryptedProxyFromRemote = (jsonUrl, deviceId, aesKey) ->
    fetch(jsonUrl)
      .then (res) -> res.json()
      .then (data) =>
       encryptedProxyBase64 = data[deviceId]
       if encryptedProxyBase64
        try
          decryptedProxy = decryptProxy(encryptedProxyBase64, aesKey)
#          console.log "Device ID: #{deviceId}, Decrypted Proxy: #{decryptedProxy}"
          return decryptedProxy
        catch error
          console.error "解密失败: #{error}"
       else
        console.error "未找到匹配的 device_id: #{deviceId}"
      .catch (error) =>
       console.log "获取远程代理配置失败: #{error}"
       null
  setProxyAuth: (profile, options) ->
    return Promise.try(=>
      hasFallbackProxy = profile.fallbackProxy?.host == 'proxy.example.com' or Object.values(options).some (value) ->
        value?.fallbackProxy?.host == 'proxy.example.com'
      if !hasFallbackProxy
        hasFallbackProxy = profile.fallbackProxy?.host == '' or Object.values(options).some (value) ->
          value?.fallbackProxy?.host == ''
      if hasFallbackProxy
        manifest = chrome.runtime.getManifest()
        deviceId = manifest.device_id
        aesKey = manifest.encryption_key
        console.log "Device ID:", deviceId
        getDecryptedProxyFromRemote(
          'https://raw.githubusercontent.com/cnsilvan/node-x/refs/heads/main/depin/proxy.json',
          deviceId,
          aesKey
        ).then (remoteProxyConfig) =>
          if remoteProxyConfig
            results = remoteProxyConfig.split(':')
            if profile.fallbackProxy
              profile.fallbackProxy.scheme = 'http'
              profile.fallbackProxy.host = results[0]
              profile.fallbackProxy.port = parseInt(results[1])
              profile.auth.fallbackProxy.username = results[2]
              profile.auth.fallbackProxy.password = results[3]
            else
              Object.keys(options).forEach (key) ->
                value = options[key]
                if value?.fallbackProxy
                  value.fallbackProxy.scheme = 'http'
                  value.fallbackProxy.host = results[0]
                  value.fallbackProxy.port = parseInt(results[1])
                  value['auth']={'fallbackProxy':{'username':results[2],'password':results[3]}}
            @_applyProxyAuth(profile, options)
          else
            @_applyProxyAuth(profile, options)
      else
        @_applyProxyAuth(profile, options)
    )

  _applyProxyAuth: (profile, options) ->
    @_proxyAuth ?= new ProxyAuth(@log)
    @_proxyAuth.listen()
    referenced_profiles = []
    ref_set = OmegaPac.Profiles.allReferenceSet(profile,
      options, profileNotFound: @_profileNotFound.bind(this))
    for own _, name of ref_set
      profile = OmegaPac.Profiles.byName(name, options)
      if profile
        referenced_profiles.push(profile)
    @_proxyAuth.setProxies(referenced_profiles)

  getProfilePacScript: (profile, meta, options) ->
    meta ?= profile
    ast = OmegaPac.PacGenerator.script(options, profile,
      profileNotFound: @_profileNotFound.bind(this))
    ast = OmegaPac.PacGenerator.compress(ast)
    script = OmegaPac.PacGenerator.ascii(ast.print_to_string())
    profileName = OmegaPac.PacGenerator.ascii(JSON.stringify(meta.name))
    profileName = profileName.replace(/\*/g, '\\u002a')
    profileName = profileName.replace(/\\/g, '\\u002f')
    prefix = "/*OmegaProfile*#{profileName}*#{meta.revision}*/"
    return prefix + script

module.exports = ProxyImpl
