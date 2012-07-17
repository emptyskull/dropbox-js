# Stripped-down OAuth implementation that works with the Dropbox API server.
class DropboxOauth
  # Creates an Oauth instance that manages an application's keys and token.
  #
  # @param {Object} options must have the following properties: key is the
  #     Dropbox application's key (consumer key, in OAuth vocabulary) and
  #     secret is the Dropbox application's secret (OAuth calls it the
  #     consumer secret)
  constructor: (options) ->
    @key = options.key
    @secret = options.secret
    @setToken null, ''

  # Sets the OAuth token to be used for future requests.
  setToken: (token, tokenSecret) ->
    @token = token
    # This is part of signing, but it's set here so it can be cached.
    @hmacKey = DropboxXhr.urlEncodeValue(@secret) + '&' +
      DropboxXhr.urlEncodeValue(tokenSecret)
    null

  # Computes the value of the Authorization HTTP header.
  #
  # This method mutates the params object, and removes all the OAuth-related
  # parameters from it.
  #
  # @param {String} method the HTTP method used to make the request ('GET',
  #     'POST', etc)
  # @param {String} url the HTTP URL (e.g. "http://www.example.com/photos")
  #     that receives the request
  # @param {Object} params an associative array (hash) containing the HTTP
  #     request parameters; the parameters should include the oauth_
  #     parameters generated by calling {@see boilerplateParams}
  # @return {String} the value to be used for the Authorization HTTP header
  authHeader: (method, url, params) ->
    # Augment params with OAuth parameters.
    @boilerplateParams params
    params.oauth_signature = @signature method, url, params

    # Collect all the OAuth parameters.
    oauth_params = []
    for param, value of params
      if param.substring(0, 6) == 'oauth_'
        oauth_params.push param
    oauth_params.sort()

    # Remove the parameters from the params hash and add them to the header.
    header = []
    for param in oauth_params
      header.push DropboxXhr.urlEncodeValue(param) + '="' +
          DropboxXhr.urlEncodeValue(params[param]) + '"'
      delete params[param]

    # NOTE: the space after the comma is optional in the OAuth spec, so we'll
    #       skip it to save some bandwidth
    'OAuth ' + header.join(',')

  # Adds boilerplate OAuth parameters to a request's parameter list.
  # 
  # This should be called right before signing a request, to maximize the
  # chances that the OAuth timestamp will be fresh.
  #
  # @param {Object} params an associative array (hash) containing the
  #     parameters for an OAuth request; the boilerplate parameters will be
  #     added to this hash
  # @return {Object} params
  boilerplateParams: (params) ->
    params.oauth_consumer_key = @key
    params.oauth_nonce = @nonce()
    params.oauth_signature_method = 'HMAC-SHA1'
    params.oauth_token = @token if @token
    params.oauth_timestamp = Math.floor(Date.now() / 1000)
    params.oauth_version = '1.0'
    params

  # Generates a nonce for an OAuth request.
  #
  # @return {String} the nonce to be used as the oauth_nonce parameter
  nonce: ->
    Date.now().toString(36) + Math.random().toString(36)

  # Computes the signature for an OAuth request.
  #
  # @param {String} method the HTTP method used to make the request ('GET',
  #     'POST', etc)
  # @param {String} url the HTTP URL (e.g. "http://www.example.com/photos")
  #     that receives the request
  # @param {Object} params an associative array (hash) containing the HTTP
  #     request parameters; the parameters should include the oauth_
  #     parameters generated by calling {@see boilerplateParams}
  # @return {String} the signature, ready to be used as the oauth_signature
  #     OAuth parameter
  signature: (method, url, params) ->
    string = method.toUpperCase() + '&' + DropboxXhr.urlEncodeValue(url) +
      '&' + DropboxXhr.urlEncodeValue(DropboxXhr.urlEncode(params))
    base64HmacSha1 string, @hmacKey

# Polyfill for Internet Explorer 8.
unless Date.now?
  Date.now = () ->
    (new Date()).getTime()

