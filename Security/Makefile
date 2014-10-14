Prog= setuid root open
setuid: setuid.c
	gcc setuid.c -o setuid
	sudo chmod a+x ./setuid
	sudo chmod u+s ./setuid
	sudo chown root:wheel ./setuid
root:
	gcc root.c -o root
	sudo chmod a+x ./root
	sudo chmod u+s ./root
	sudo chown root:wheel ./root

clean:
	sudo rm -rf $(Prog)

