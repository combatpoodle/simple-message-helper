'use strict'

describe 'message-helper', ->
  callbacks = undefined
  amqp = undefined
  exchanges = undefined
  queues = undefined
  connection = undefined

  readyFn = undefined
  callbackFn = undefined
  errbackFn = undefined
  MessageHelper = undefined

  beforeEach ->
    callbacks = {}

    process.env = {}

    amqp = 
      createConnection: (connectionInfo) ->
        return connection

    exchanges = {
      "hubot-commands": {
        on: (event, fn) ->
        publish: (routingKey, message) ->
      },
      "hubot-responses": {
        on: (event, fn) ->
        publish: (routingKey, message) ->
      }
    }

    queues = {
      "hubot-responses": {
        on: (event, fn) ->
        bind: (exchange, routingKey, callback) ->
          callbacks["queue-bound"] = callback
        subscribe: (callback) ->
          callbacks["queue-subscribe"] = callback
      }
    }

    connection =
      on: (event, callback) ->
        callbacks["connection-#{event}"] = callback

      queue: (queueName, callback) ->
        callbacks["queue-#{queueName}-declared"] = callback
        return queues[queueName]

      exchange: (exchangeName, options, callback) ->
        callbacks["exchange-#{exchangeName}-declared"] = callback
        return exchanges[exchangeName]

      disconnect: () ->

    spyOn(amqp, "createConnection").and.callThrough()

    spyOn(connection, "on").and.callThrough()
    spyOn(connection, "queue").and.callThrough()
    spyOn(connection, "exchange").and.callThrough()
    spyOn(connection, "disconnect").and.callThrough()

    spyOn(queues["hubot-responses"], "bind").and.callThrough()
    spyOn(queues["hubot-responses"], "subscribe").and.callThrough()

    spyOn(exchanges["hubot-commands"], "publish").and.callThrough()
    spyOn(exchanges["hubot-responses"], "publish").and.callThrough()

    MessageHelper = require('../src/message-helper')(amqp)

    readyFn = jasmine.createSpy("readyFn() spy")
    callbackFn = jasmine.createSpy("callbackFn() spy")
    errbackFn = jasmine.createSpy("errbackFn() spy")

  it 'starts up to a sane state', (done) ->
    messageHelper = new MessageHelper readyFn, callbackFn, errbackFn

    readyPromiseFn = jasmine.createSpy("readyPromiseFn() spy")
    messageHelper.readyPromise().then(readyPromiseFn)

    defaultCall = { host: "127.0.0.1", login: "guest", password: "guest", port: "5672", vhost: "/" }

    if "connection prep triggered"
      expect(amqp.createConnection).toHaveBeenCalledWith defaultCall
      expect(connection.on).toHaveBeenCalledWith "ready", callbacks["connection-ready"]
      expect(connection.on).toHaveBeenCalledWith "close", callbacks["connection-close"]
      expect(connection.on).toHaveBeenCalledWith "error", callbacks["connection-error"]

      connection.on.calls.reset()

      expect(messageHelper.isReady()).toEqual false
      expect(messageHelper.isReady("exchange")).toEqual false
      expect(messageHelper.isReady("queue")).toEqual false
      expect(readyPromiseFn.calls.count()).toEqual 0

    callbacks["connection-ready"]()

    if "hubot-responses exchange declared"
      expect(callbacks["queue-hubot-responses-declared"]).not.toEqual(undefined)
      expect(connection.queue).toHaveBeenCalledWith "hubot-responses", callbacks["queue-hubot-responses-declared"]
      expect(connection.queue.calls.count()).toEqual 1

      connection.queue.calls.reset()

    callbacks["queue-hubot-responses-declared"](queues["hubot-responses"])

    if "hubot-commands exchange declared"
      expect(callbacks["exchange-hubot-commands-declared"]).not.toEqual(undefined)
      expect(connection.exchange).toHaveBeenCalledWith "hubot-commands", {}, callbacks["exchange-hubot-commands-declared"]
      expect(connection.exchange.calls.count()).toEqual 1

      connection.exchange.calls.reset()

    callbacks["exchange-hubot-commands-declared"](exchanges["hubot-commands"])

    if "hubot-responses queue declared"
      expect(callbacks["exchange-hubot-responses-declared"]).not.toEqual(undefined)
      expect(connection.exchange).toHaveBeenCalledWith "hubot-responses", {}, callbacks["exchange-hubot-responses-declared"]
      expect(connection.exchange.calls.count()).toEqual 1
      expect(messageHelper.isReady("exchange")).toEqual false

      connection.exchange.calls.reset()

    callbacks["exchange-hubot-responses-declared"](exchanges["hubot-responses"])

    if "hubot-responses queue declared"
      expect(callbacks["queue-bound"]).not.toEqual(undefined)
      expect(queues["hubot-responses"].bind).toHaveBeenCalledWith "hubot-responses", "#", callbacks["queue-bound"]
      expect(queues["hubot-responses"].bind.calls.count()).toEqual 1
      expect(messageHelper.isReady("exchange")).toEqual true

      queues["hubot-responses"].bind.calls.reset()
      connection.exchange.calls.reset()

    callbacks["queue-bound"]()

    if "hubot-responses queue subscribed"
      expect(callbacks["queue-subscribe"]).not.toEqual(undefined)
      expect(queues["hubot-responses"].subscribe).toHaveBeenCalledWith callbacks["queue-subscribe"]

      expect(readyFn.calls.count()).toEqual(1)
      expect(callbackFn.calls.count()).toEqual(0)
      expect(errbackFn.calls.count()).toEqual(0)

      process.nextTick ->
        expect(readyPromiseFn.calls.count()).toEqual 1
        done()

  it 'uses environmental variables for connection info', ->
    process.env.AMQP_USER = "amqp_user"
    process.env.AMQP_PASSWORD = "amqp_password"
    process.env.AMQP_HOST = "amqp_host"
    process.env.AMQP_PORT = "amqp_port"
    process.env.AMQP_VHOST = "amqp_vhost"
    process.env.AMQP_COMMAND_EXCHANGE_NAME = "amqp_command_exchange_name"
    process.env.AMQP_COMMAND_ROUTING_KEY = "amqp_command_routing_key"
    process.env.AMQP_RESPONSE_EXCHANGE_NAME = "amqp_response_exchange_name"
    process.env.AMQP_RESPONSE_QUEUE_NAME = "amqp_response_queue_name"

    expectedConnectionInfo = { login : 'guest', password : 'amqp_password', host : 'amqp_host', port : 'amqp_port', vhost : 'amqp_vhost' }

    exchanges = {
      "amqp_command_exchange_name": "hubot-commands",
      "amqp_response_exchange_name": "hubot-responses"
    }

    queues = {
      "amqp_response_queue_name": queues["hubot-responses"]
    }

    messageHelper = new MessageHelper readyFn, callbackFn, errbackFn

    expect(amqp.createConnection).toHaveBeenCalledWith expectedConnectionInfo

    callbacks["connection-ready"]()
    callbacks["queue-amqp_response_queue_name-declared"](queues["amqp_response_queue_name"])
    callbacks["exchange-amqp_command_exchange_name-declared"](exchanges["amqp_command_exchange_name"])
    callbacks["exchange-amqp_response_exchange_name-declared"](exchanges["amqp_response_exchange_name"])
    callbacks["queue-bound"]()

  it 'should receive messages and trigger the callback', ->
    messageHelper = new MessageHelper readyFn, callbackFn, errbackFn

    callbacks["connection-ready"]()
    callbacks["queue-hubot-responses-declared"](queues["hubot-responses"])
    callbacks["exchange-hubot-commands-declared"](exchanges["hubot-commands"])
    callbacks["exchange-hubot-responses-declared"](exchanges["hubot-responses"])
    callbacks["queue-bound"]()

    expect(readyFn.calls.count()).toEqual(1)
    expect(callbackFn.calls.count()).toEqual(0)
    expect(errbackFn.calls.count()).toEqual(0)

    callbacks["queue-subscribe"] '"this is a great message"'

    expect(readyFn.calls.count()).toEqual(1)
    expect(callbackFn.calls.count()).toEqual(1)
    expect(errbackFn.calls.count()).toEqual(0)

    expect(callbackFn).toHaveBeenCalledWith 'this is a great message'

  it 'should send messages', ->
    messageHelper = new MessageHelper readyFn, callbackFn, errbackFn

    callbacks["connection-ready"]()
    callbacks["queue-hubot-responses-declared"](queues["hubot-responses"])
    callbacks["exchange-hubot-commands-declared"](exchanges["hubot-commands"])
    callbacks["exchange-hubot-responses-declared"](exchanges["hubot-responses"])
    callbacks["queue-bound"]()

    messageHelper.send "hello there"

    expect(exchanges["hubot-commands"].publish).toHaveBeenCalledWith "hubot-commands", '"hello there"'

  it 'should handle disconnects', ->
    messageHelper = new MessageHelper readyFn, callbackFn, errbackFn

    callbacks["connection-ready"]()
    callbacks["queue-hubot-responses-declared"](queues["hubot-responses"])
    callbacks["exchange-hubot-commands-declared"](exchanges["hubot-commands"])
    callbacks["exchange-hubot-responses-declared"](exchanges["hubot-responses"])
    callbacks["queue-bound"]()

    messageHelper.send "hello there"

    expect(exchanges["hubot-commands"].publish).toHaveBeenCalledWith "hubot-commands", '"hello there"'

    expect(readyFn.calls.count()).toEqual(1)
    expect(callbackFn.calls.count()).toEqual(0)
    expect(errbackFn.calls.count()).toEqual(0)

    expect(messageHelper.isReady()).toEqual true

    callbacks["connection-close"]()

    expect(readyFn.calls.count()).toEqual(1)
    expect(callbackFn.calls.count()).toEqual(0)
    expect(errbackFn.calls.count()).toEqual(1)

    expect(messageHelper.isReady()).toEqual false

    callbacks["connection-ready"]()
    callbacks["queue-hubot-responses-declared"](queues["hubot-responses"])
    callbacks["exchange-hubot-commands-declared"](exchanges["hubot-commands"])
    callbacks["exchange-hubot-responses-declared"](exchanges["hubot-responses"])
    callbacks["queue-bound"]()

    expect(readyFn.calls.count()).toEqual(2)

    expect(messageHelper.isReady()).toEqual true

  it 'should disconnect OK', ->
    messageHelper = new MessageHelper readyFn, callbackFn, errbackFn

    callbacks["connection-ready"]()
    callbacks["queue-hubot-responses-declared"](queues["hubot-responses"])
    callbacks["exchange-hubot-commands-declared"](exchanges["hubot-commands"])
    callbacks["exchange-hubot-responses-declared"](exchanges["hubot-responses"])
    callbacks["queue-bound"]()

    messageHelper.send "hello there"

    expect(exchanges['hubot-commands'].publish).toHaveBeenCalledWith("hubot-commands", '"hello there"')

    expect(readyFn.calls.count()).toEqual(1)
    expect(callbackFn.calls.count()).toEqual(0)
    expect(errbackFn.calls.count()).toEqual(0)

    expect(messageHelper.isReady()).toEqual true

    messageHelper.shutDown()

    expect(connection.disconnect).toHaveBeenCalled
    expect(errbackFn.calls.count()).toEqual(0)