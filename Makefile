BUILDFOLDER:=build

soko.com:
	mkdir -p $(BUILDFOLDER)
	nasm main.asm -f bin -o $(BUILDFOLDER)/soko.com

run: soko.com
	dosbox $(BUILDFOLDER)/soko.com
