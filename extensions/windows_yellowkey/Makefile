EXTENSION := windows_yellowkey
PKG       := .

.PHONY: all windows amd64 arm64 deps tidy clean

all: windows

windows: amd64 arm64

amd64:
	GOARCH=amd64 GOOS=windows go build -trimpath -ldflags="-s -w" -o $(EXTENSION)-amd64.exe $(PKG)

arm64:
	GOARCH=arm64 GOOS=windows go build -trimpath -ldflags="-s -w" -o $(EXTENSION)-arm64.exe $(PKG)

deps tidy:
	go mod tidy

clean:
	rm -f $(EXTENSION)-amd64.exe $(EXTENSION)-arm64.exe
