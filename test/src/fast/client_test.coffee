describe 'Dropbox.Client', ->
  beforeEach ->
    @client = new Dropbox.Client
      key: 'mock00key',
      token: 'mock00token',
      uid: 3141592,
      server: 'https://api.no-calls-in-fasttests.com'

  describe 'with custom API server URLs', ->
    it 'computes the other URLs correctly', ->
      client = new Dropbox.Client
        key: 'mock00key',
        server: 'https://api.sandbox.dropbox-proxy.com'

      expect(client.apiServer).to.equal(
        'https://api.sandbox.dropbox-proxy.com')
      expect(client.authServer).to.equal(
        'https://www.sandbox.dropbox-proxy.com')
      expect(client.fileServer).to.equal(
        'https://api-content.sandbox.dropbox-proxy.com')

  describe '#normalizePath', ->
    it "doesn't touch relative paths", ->
      expect(@client.normalizePath('aa/b/cc/dd')).to.equal 'aa/b/cc/dd'

    it 'removes the leading / from absolute paths', ->
      expect(@client.normalizePath('/aaa/b/cc/dd')).to.equal 'aaa/b/cc/dd'

    it 'removes multiple leading /s from absolute paths', ->
      expect(@client.normalizePath('///aa/b/ccc/dd')).to.equal 'aa/b/ccc/dd'

  describe '#urlEncodePath', ->
    it 'encodes each segment separately', ->
      expect(@client.urlEncodePath('a b+c/d?e"f/g&h')).to.
          equal "a%20b%2Bc/d%3Fe%22f/g%26h"
    it 'normalizes paths', ->
      expect(@client.urlEncodePath('///a b+c/g&h')).to.
          equal "a%20b%2Bc/g%26h"

  describe '#dropboxUid', ->
    it 'matches the uid in the credentials', ->
      expect(@client.dropboxUid()).to.equal 3141592

  describe '#reset', ->
    beforeEach ->
      @authSteps = []
      @client.onAuthStepChange.addListener (client) =>
        @authSteps.push client.authStep
      @client.reset()

    it 'gets the client into the RESET state', ->
      expect(@client.authStep).to.equal Dropbox.Client.RESET

    it 'removes token and uid information', ->
      credentials = @client.credentials()
      expect(credentials).not.to.have.property 'token'
      expect(credentials).not.to.have.property 'uid'

    it 'triggers onAuthStepChange', ->
      expect(@authSteps).to.deep.equal [Dropbox.Client.RESET]

    it 'does not trigger onAuthStep if already reset', ->
      @authSteps = []
      @client.reset()
      expect(@authSteps).to.deep.equal []

  describe '#credentials', ->
    it 'contains all the expected keys when DONE', ->
      credentials = @client.credentials()
      expect(credentials).to.have.property 'key'
      expect(credentials).to.have.property 'token'
      expect(credentials).to.have.property 'uid'

    it 'contains all the expected keys when RESET', ->
      @client.reset()
      credentials = @client.credentials()
      expect(credentials).to.have.property 'key'

    describe 'for a client with raw keys', ->
      beforeEach ->
        @client.setCredentials(
          key: 'dpf43f3p2l4k3l03', secret: 'kd94hf93k423kf44',
          token: 'user-token', uid: '1234567')

      it 'contains all the expected keys when DONE', ->
        credentials = @client.credentials()
        expect(credentials).to.have.property 'key'
        expect(credentials).to.have.property 'secret'
        expect(credentials).to.have.property 'token'
        expect(credentials).to.have.property 'uid'

      it 'contains all the expected keys when RESET', ->
        @client.reset()
        credentials = @client.credentials()
        expect(credentials).to.have.property 'key'
        expect(credentials).to.have.property 'secret'

  describe '#setCredentials', ->
    it 'gets the client into the RESET state', ->
      @client.setCredentials key: 'app-key', secret: 'app-secret'
      expect(@client.authStep).to.equal Dropbox.Client.RESET
      credentials = @client.credentials()
      expect(credentials.key).to.equal 'app-key'
      expect(credentials.secret).to.equal 'app-secret'

    it 'gets the client into the DONE state', ->
      @client.setCredentials(
          key: 'app-key', secret: 'app-secret', token: 'user-token',
          uid: '3141592')
      expect(@client.authStep).to.equal Dropbox.Client.DONE
      credentials = @client.credentials()
      expect(credentials.key).to.equal 'app-key'
      expect(credentials.secret).to.equal 'app-secret'
      expect(credentials.token).to.equal 'user-token'
      expect(credentials.uid).to.equal '3141592'

    beforeEach ->
      @authSteps = []
      @client.onAuthStepChange.addListener (client) =>
        @authSteps.push client.authStep

    it 'triggers onAuthStepChange when switching from DONE to RESET', ->
      @client.setCredentials key: 'app-key', secret: 'app-secret'
      expect(@authSteps).to.deep.equal [Dropbox.Client.RESET]

    it 'does not trigger onAuthStepChange when not switching', ->
      @client.setCredentials key: 'app-key', secret: 'app-secret'
      @authSteps = []
      @client.setCredentials key: 'app-key', secret: 'app-secret'
      expect(@authSteps).to.deep.equal []

  describe '#authenticate', ->
    describe 'without an OAuth driver', ->
      beforeEach ->
        @stubbed = Dropbox.AuthDriver.autoConfigure
        @stubDriver =
          authType: -> 'token'
          url: -> 'http://stub.url/'
        Dropbox.AuthDriver.autoConfigure = (client) =>
          client.authDriver @stubDriver

      afterEach ->
        Dropbox.AuthDriver.autoConfigure = @stubbed

      it 'calls autoConfigure when no OAuth driver is supplied', (done) ->
        @client.reset()
        @client.authDriver null
        @stubDriver.doAuthorize = (authUrl, stateParam, client) =>
          expect(client).to.equal @client
          done()
        @client.authenticate null

      it 'raises an exception when AuthDriver.autoConfigure fails', ->
        @client.reset()
        @client.authDriver null
        @stubDriver = null
        expect(=> @client.authenticate null).to.
            throw Error, /auto-configuration failed/i

    it 'completes without an OAuth driver if already in DONE', (done) ->
      @client.authDriver null
      @client.authenticate (error, client) =>
        expect(error).to.equal null
        expect(client).to.equal @client
        done()

    it 'complains if called when the client is in ERROR', ->
      @client.authDriver doAuthorize: ->
        assert false, 'The OAuth driver should not be invoked'
      @client.authStep = Dropbox.Client.ERROR
      expect(=> @client.authenticate null).to.throw Error, /error.*reset/i

    describe 'with interactive: false', ->
      beforeEach ->
        @driver =
          doAuthorize: ->
            assert false, 'The OAuth driver should not be invoked'
          url: ->
            'https://localhost:8912/oauth_redirect'
        @client.authDriver @driver

      it 'stops at RESET with interactive: false', (done) ->
        @client.reset()
        @client.authenticate interactive: false, (error, client) ->
          expect(error).to.equal null
          expect(client.authStep).to.equal Dropbox.Client.RESET
          done()

      it 'stops at PARAM_SET with interactive: false', (done) ->
        @client.reset()
        @client.oauth.setAuthStateParam 'state_should_not_be_used'
        @client.authStep = @client.oauth.step()
        expect(@client.authStep).to.equal Dropbox.Client.PARAM_SET
        @client.authenticate interactive: false, (error, client) ->
          expect(error).to.equal null
          expect(client.authStep).to.equal Dropbox.Client.PARAM_SET
          done()

      it 'proceeds from PARAM_LOADED with interactive: false', (done) ->
        @client.reset()
        credentials = @client.credentials()
        credentials.oauthStateParam = 'state_should_not_be_used'
        @client.setCredentials credentials
        expect(@client.authStep).to.equal Dropbox.Client.PARAM_LOADED
        @client.authenticate interactive: false, (error, client) ->
          expect(error).to.equal null
          expect(client.authStep).to.equal Dropbox.Client.PARAM_SET
          done()

      it 'calls resumeAuthorize from PARAM_LOADED when defined', (done) ->
        @driver.resumeAuthorize = (stateParam, client, callback) ->
          expect(stateParam).to.equal 'state_should_not_be_used'
          expect(client.authStep).to.equal Dropbox.Client.PARAM_LOADED
          done()
        @client.reset()
        credentials = @client.credentials()
        credentials.oauthStateParam = 'state_should_not_be_used'
        @client.setCredentials credentials
        expect(@client.authStep).to.equal Dropbox.Client.PARAM_LOADED
        @client.authenticate (error, client) ->
          expect('callback_should_not_be_called').to.equal false
          done()

    describe '#constructor', ->
      it 'raises an Error if initialized without an API key / secret', ->
        expect(-> new Dropbox.Client(token: '123')).to.
            throw(Error, /no api key/i)