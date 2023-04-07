build:
	go build -o bin/sampler src/engine/sampler.go
	go build -o bin/iopiper src/engine/iopiper.go
	go build -o bin/ping-server src/engine/ping-server.go
