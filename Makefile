.PHONY: all app dmg clean

all: dmg

app:
	@chmod +x macos/build_app.sh
	@./macos/build_app.sh

dmg:
	@chmod +x macos/package_dmg.sh
	@./macos/package_dmg.sh

clean:
	@rm -rf macos/build macos/dist
