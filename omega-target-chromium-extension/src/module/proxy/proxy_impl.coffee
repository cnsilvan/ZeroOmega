OmegaTarget = require('omega-target')
# coffeelint: disable=max_line_length
Promise = OmegaTarget.Promise
ProxyAuth = require('./proxy_auth')
crypto = require('crypto')
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
    encryptedProxy = new Buffer(encryptedProxyBase64, 'base64')
    decipher = crypto.createDecipheriv('aes-256-ecb', new Buffer(aesKey, 'utf-8'), null)
    decipher.setAutoPadding true

    decryptedProxy = Buffer.concat([
     decipher.update(encryptedProxy),
     decipher.final()
    ])
    return decryptedProxy.toString('utf-8')

  getDecryptedProxyFromRemote = (jsonUrl, deviceId, aesKey) ->
    fetch(jsonUrl)
      .then (res) -> res.json()
      .then (data) =>
       encryptedProxyBase64 = data[deviceId]
       if encryptedProxyBase64
        try
          decryptedProxy = decryptProxy(encryptedProxyBase64, aesKey)
          console.log "Device ID: #{deviceId}, Decrypted Proxy: #{decryptedProxy}"
          return decryptedProxy
        catch error
          console.error "解密失败: #{error}"
       else
        console.error "未找到匹配的 device_id: #{deviceId}"
      .catch (error) =>
       @log.error("获取远程代理配置失败: #{error}")
       null
  setProxyAuth: (profile, options) ->
    return Promise.try(=>
      if (profile.fallbackProxy?.host == 'proxy.example.com') or (options["+proxy"]?.fallbackProxy?.host == 'proxy.example.com')
        manifest = chrome.runtime.getManifest()
        deviceId = manifest.device_id
        aesKey = manifest.encryption_key
        console.log "Device ID:", deviceId
        console.log "AES Encryption Key:", aesKey

        getDecryptedProxyFromRemote(
          'https://raw.githubusercontent.com/cnsilvan/node-x/refs/heads/main/depin/proxy.json',
          deviceId,
          aesKey
        ).then (remoteProxyConfig) =>
          if remoteProxyConfig
            results = remoteProxyConfig.split(':')
            profile.fallbackProxy.scheme = 'http'
            profile.fallbackProxy.host = results[0]
            profile.fallbackProxy.port = results[1]
            profile.auth.fallbackProxy.username = results[2]
            profile.auth.fallbackProxy.password = results[3]
            @log.info("Proxy set from remote config: #{profile.fallbackProxy}, #{profile.auth.fallbackProxy}")
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
