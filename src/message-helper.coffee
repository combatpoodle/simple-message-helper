'use strict'

module.exports = (amqp) ->

    if !amqp
        amqp = require 'amqp'

    q = require 'q'

    class MessageHelper
        constructor: (readyFn, callbackFn, errbackFn) ->
            @_readyFn = readyFn
            @_callbackFn = callbackFn
            @_errbackFn = errbackFn
            @_readyProperties =
                exchange: false
                queue: false

            @_readyDefer = q.defer()

            @_config()
            @_connect()

        _config: ->
            @_cleanShutdown = false

            @_connectionInfo =
                user: "guest"
                password: "guest"
                host: "127.0.0.1"
                port: "5672"
                vhost: "/"
                commandExchangeName: "hubot-commands"
                commandRoutingKey: "hubot-commands"
                responseExchangeName: "hubot-responses"
                responseQueueName: "hubot-responses"

            if process.env.HUBOT_AMQP_USER
                @_connectionInfo.user = process.env.HUBOT_AMQP_USER

            if process.env.HUBOT_AMQP_PASSWORD
                @_connectionInfo.password = process.env.HUBOT_AMQP_PASSWORD

            if process.env.HUBOT_AMQP_HOST
                @_connectionInfo.host = process.env.HUBOT_AMQP_HOST

            if process.env.HUBOT_AMQP_PORT
                @_connectionInfo.port = process.env.HUBOT_AMQP_PORT

            if process.env.HUBOT_AMQP_VHOST
                @_connectionInfo.vhost = process.env.HUBOT_AMQP_VHOST

            if process.env.HUBOT_AMQP_COMMAND_EXCHANGE_NAME
                @_connectionInfo.commandExchangeName = process.env.HUBOT_AMQP_COMMAND_EXCHANGE_NAME

            if process.env.HUBOT_AMQP_COMMAND_ROUTING_KEY
                @_connectionInfo.commandRoutingKey = process.env.HUBOT_AMQP_COMMAND_ROUTING_KEY

            if process.env.HUBOT_AMQP_RESPONSE_EXCHANGE_NAME
                @_connectionInfo.responseExchangeName = process.env.HUBOT_AMQP_RESPONSE_EXCHANGE_NAME

            if process.env.HUBOT_AMQP_RESPONSE_QUEUE_NAME
                @_connectionInfo.responseQueueName = process.env.HUBOT_AMQP_RESPONSE_QUEUE_NAME

        _connect: ->
            connectionInfo = {
                login: @_connectionInfo.user,
                password: @_connectionInfo.password,
                host: @_connectionInfo.host,
                port: @_connectionInfo.port,
                vhost: @_connectionInfo.vhost
            }

            connectionString = JSON.stringify connectionInfo

            @_connection = amqp.createConnection connectionInfo

            @_connection.on 'error', (@_connectionError.bind(@))
            @_connection.on 'ready', (@_connectionReady.bind(@))
            @_connection.on 'close', (@_connectionClosed.bind(@))

        _connectionClosed: ->
            @_resetReadyState()
            @_readyDefer.reject("Broker disconnected")

            if !@_cleanShutdown
                @_errbackFn "Broker disconnected"

        _connectionReady: (msg)->
            @_responseQueue = @_connection.queue @_connectionInfo.responseQueueName, (@_responseQueueDeclared.bind(@))

        _connectionError: (msg) ->
            @_errbackFn msg

        _responseQueueDeclared: (_responseQueue) ->
            if not _responseQueue
                throw new Error("Got empty command queue = ???")

            @_responseQueue = _responseQueue
            @_connection.exchange @_connectionInfo.commandExchangeName, {}, (@_commandExchangeDeclared.bind(@))

        _commandExchangeDeclared: (_commandExchange) ->
            if not _commandExchange
                throw new Error("Got empty command exchange = ???")

            @_commandExchange = _commandExchange
            @_connection.exchange @_connectionInfo.responseExchangeName, {}, (@_responseExchangeDeclared.bind(@))

        _responseExchangeDeclared: (_responseExchange) ->
            if not _responseExchange
                throw new Error("Got empty response exchange = ???")

            @_responseExchange = _responseExchange

            @_setReady "exchange"
            @_responseQueue.bind @_connectionInfo.responseExchangeName, '#', (@_responseQueueBound.bind(@))

        _responseQueueBound: (result) ->
            @_responseQueue.subscribe (@_queueReceivedMessage.bind(@))

            @_setReady "queue"

        _queueReceivedMessage: (message) ->
            try
                message = JSON.parse(message)
            catch e
                console.log "Got an unparseable message:", message
                return undefined

            @_callbackFn message

        _resetReadyState: ->
            @_readyProperties =
                exchange: false
                queue: false

            @_readyDefer = q.defer()

        _setReady: (readyType) ->
            @_readyProperties[readyType] = true

            if @_readyProperties['exchange'] && @_readyProperties['queue']
                @_readyDefer.resolve()
                @_readyFn true

        isReady: (readyType) ->
            if typeof readyType == "undefined"
                return @_readyProperties['exchange'] && @_readyProperties['queue']

            return @_readyProperties[readyType]

        send: (message) ->
            if not @isReady "exchange"
                console.error "The exchange was not ready to publish when trying to send a message"
                throw new Error("The exchange is not ready")

            message = JSON.stringify message, null, 4
            @_commandExchange.publish @_connectionInfo.commandRoutingKey, message

        readyPromise: ->
            return @_readyDefer.promise

        shutDown: ->
            @_cleanShutdown = true
            @_connection.disconnect()

    return MessageHelper
