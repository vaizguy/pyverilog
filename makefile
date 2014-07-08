filelist.so: filelist.pyx
	./setup.py build_ext --inplace

filelist.c: filelist.pyx
	/home/aananth/bin/cython --embed filelist.pyx

filelist: filelist.c
	gcc -I /home/aananth/include/python2.7/ -o filelist filelist.c -L /home/aananth/lib/ -lpython2.7 -lpthread -lm -lutil -ldl
