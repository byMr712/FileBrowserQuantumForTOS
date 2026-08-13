package main

import (
	"archive/tar"
	"io"
	"log"
	"os"
	"path/filepath"
	"time"
)

type Entry struct {
	Name  string
	Mode  int64
	IsDir bool
}

func main() {
	if len(os.Args) != 3 {
		log.Fatal("usage: tarmake <srcDir> <outTar>")
	}
	srcDir := os.Args[1]
	outTar := os.Args[2]

	entries := []Entry{
		{Name: "FileBrowserQuantum.lang", Mode: 0644},
		{Name: "INFO", Mode: 0755},
		{Name: "bin", Mode: 0755, IsDir: true},
		{Name: "bin/program", Mode: 0755, IsDir: true},
		{Name: "bin/program/filebrowserquantum", Mode: 0744},
		{Name: "bin/filebrowser.yml", Mode: 0644},
		{Name: "bin/filebrowser.migrate.yml", Mode: 0644},
		{Name: "config.ini", Mode: 0644},
		{Name: "functions", Mode: 0755, IsDir: true},
		{Name: "functions/dependapps.sh", Mode: 0744},
		{Name: "images", Mode: 0755, IsDir: true},
		{Name: "images/icons", Mode: 0755, IsDir: true},
		{Name: "images/icons/FileBrowserQuantum.png", Mode: 0644},
		{Name: "init.d", Mode: 0755, IsDir: true},
		{Name: "init.d/service", Mode: 0755},
		{Name: "version", Mode: 0644},
		{Name: "webui.bz2", Mode: 0644},
	}

	f, err := os.Create(outTar)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	tw := tar.NewWriter(f)
	mtime := time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC)

	for _, e := range entries {
		hdr := &tar.Header{
			Name:    e.Name,
			Mode:    e.Mode,
			Uid:     0,
			Gid:     0,
			Uname:   "root",
			Gname:   "root",
			ModTime: mtime,
			Format:  tar.FormatGNU,
		}
		if e.IsDir {
			hdr.Typeflag = tar.TypeDir
			hdr.Name = e.Name + "/"
			if err := tw.WriteHeader(hdr); err != nil {
				log.Fatal(err)
			}
			continue
		}
		hdr.Typeflag = tar.TypeReg
		src := filepath.Join(srcDir, filepath.FromSlash(e.Name))
		st, err := os.Stat(src)
		if err != nil {
			log.Fatal(err)
		}
		hdr.Size = st.Size()
		if err := tw.WriteHeader(hdr); err != nil {
			log.Fatal(err)
		}
		in, err := os.Open(src)
		if err != nil {
			log.Fatal(err)
		}
		if _, err := io.Copy(tw, in); err != nil {
			log.Fatal(err)
		}
		in.Close()
	}
	if err := tw.Close(); err != nil {
		log.Fatal(err)
	}
	f.Close()
	log.Printf("wrote %s (%d bytes)", outTar, stSize(outTar))
}

func stSize(p string) int64 {
	st, _ := os.Stat(p)
	return st.Size()
}
