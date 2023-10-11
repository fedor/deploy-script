const http = require("http")
const process = require('process')
const { readdir } = require('fs')
require('dotenv').config()

let isDaemon = false
if (process.argv.length > 2 && process.argv[2] === '--daemon') {
	isDaemon = true
}

const startAt = new Date()
const { ENV } = process.env
const server = http.createServer(async function (req, res) {
	res.writeHead(200)
	const now = new Date()
	const str = `${now.toUTCString()}: Started at ${startAt.toUTCString()}; ENV: ${ENV}; isDaemon: ${isDaemon}`
	console.log(str)
	res.end(str)
})

// If started as a daemon, we assume that the app was started by systemd, thus a socket with the
// file-descriptor number 3 served by the systemd musts be used instead of listening to a host+port
if (isDaemon) {
	server.listen({ fd: 3 }, () => console.log(`Server is running on { fd: 3 }`))
} else {
	server.listen(8080, '0.0.0.0', () => console.log(`Server is running on http://0.0.0.0:8080`))
}
