# Message Helper

This simplifies interactions for working with a message broker when you really don't need a full feature set - basically just send and receive.  It's written in CoffeeScript and is used downstream to run chatops tasks as part of a Hubot deployment.

### Basic usage

```javascript
var readyFn = function() {
    console.log("Connected and configured");

    communicator.send("Do stuff");
};

var messageHandler = function(message) {
    console.log("Got a message:", message);
};

var disconnected = function() {
    console.log("Disconnected");
}

var messageHelper = require('message-helper')
var communicator = new messageHelper(readyFn, messageHandler, disconnected);
```

From the above, you'd expect the message "Do stuff" to get published to your exchange.

### Configuration
You can use the default configuration:
```coffeescript
configuration =
    user: "guest"
    password: "guest"
    host: "localhost"
    port: 5672
    vhost: "/"
    commandExchangeName: "hubot-commands"
    commandRoutingKey: "hubot-commands"
    responseExchangeName: "hubot-responses"
    responseQueueName: "hubot-responses"
```

Or, use custom environment variables:
```bash
export AMQP_USER="amqp_user"
export AMQP_PASSWORD="amqp_password"
export AMQP_HOST="amqp_host"
export AMQP_PORT="amqp_port"
export AMQP_VHOST="amqp_vhost"
export AMQP_COMMAND_EXCHANGE_NAME="amqp_command_exchange_name"
export AMQP_COMMAND_ROUTING_KEY="amqp_command_routing_key"
export AMQP_RESPONSE_EXCHANGE_NAME="amqp_response_exchange_name"
export AMQP_RESPONSE_QUEUE_NAME="amqp_response_queue_name"
```
