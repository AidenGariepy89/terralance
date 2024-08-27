The client needs:
- Open a connection
- DURING PLAYER TURN
    - send a 'command' to the server
    - listen for response
- AFTER PLAYER TURN
    - listen for game updates
    - listen for signal that it is client's turn again
- Recover from errors and attempt to reconnect if disconnected

The server needs:
- The ability to load a GameState and run moves on it in a multi-threaded environment

client sends command
get access to the GameState
run the command
get the results
send the results to the client
send any necessary results to additional clients
