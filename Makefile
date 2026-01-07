
install:
	go install github.com/hitzhangjie/gitbook@latest
	brew install --cask calibre
	#brew install pandoc
	#brew install --cask basictex && echo 'export PATH="/Library/TeX/texbin:$PATH"' >> ~/.zprofile && source ~/.zprofile

init:
	gitbook init

serve:
	gitbook serve

#build:
#	gitbook pdf ./ ./build/Inside-VictoriaMetrics-ahfuzhang.pdf
#	gitbook epub ./ ./build/Inside-VictoriaMetrics-ahfuzhang.epub

.PHONY: install init serve
