package main

import (
	"archive/tar"
	"io"
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

func getMode(relPath string, isDir bool) int64 {
	if isDir {
		return 0755
	}
	switch relPath {
	case "INFO", "init.d/service":
		return 0755
	case "bin/program/filebrowserquantum", "functions/dependapps.sh":
		return 0744
	default:
		if strings.HasPrefix(relPath, "bin/program/") {
			return 0744
		}
		if strings.HasPrefix(relPath, "init.d/") {
			return 0755
		}
		if strings.HasSuffix(relPath, ".sh") {
			return 0744
		}
		return 0644
	}
}

type fileEntry struct {
	relPath string
	isDir   bool
	mode    int64
	absPath string
	size    int64
}

func main() {
	if len(os.Args) != 3 {
		log.Fatal("usage: tarmake <srcDir> <outTar>")
	}
	srcDir, err := filepath.Abs(os.Args[1])
	if err != nil {
		log.Fatal(err)
	}
	outTar := os.Args[2]

	var entries []fileEntry

	err = filepath.WalkDir(srcDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if path == srcDir {
			return nil
		}
		rel, err := filepath.Rel(srcDir, path)
		if err != nil {
			return err
		}
		relSlash := filepath.ToSlash(rel)
		base := filepath.Base(rel)
		if base == ".git" || base == "Thumbs.db" || base == "Desktop.ini" || base == ".DS_Store" {
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}

		var size int64
		isDir := d.IsDir()
		if !isDir {
			info, err := d.Info()
			if err != nil {
				return err
			}
			size = info.Size()
		}

		entries = append(entries, fileEntry{
			relPath: relSlash,
			isDir:   isDir,
			mode:    getMode(relSlash, isDir),
			absPath: path,
			size:    size,
		})
		return nil
	})
	if err != nil {
		log.Fatal(err)
	}

	// Sort entries deterministically
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].relPath < entries[j].relPath
	})

	f, err := os.Create(outTar)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	tw := tar.NewWriter(f)
	mtime := time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC)

	for _, e := range entries {
		hdr := &tar.Header{
			Name:    e.relPath,
			Mode:    e.mode,
			Uid:     0,
			Gid:     0,
			Uname:   "root",
			Gname:   "root",
			ModTime: mtime,
			Format:  tar.FormatGNU,
		}
		if e.isDir {
			hdr.Typeflag = tar.TypeDir
			hdr.Name = e.relPath + "/"
			if err := tw.WriteHeader(hdr); err != nil {
				log.Fatal(err)
			}
			continue
		}
		hdr.Typeflag = tar.TypeReg
		hdr.Size = e.size
		if err := tw.WriteHeader(hdr); err != nil {
			log.Fatal(err)
		}
		in, err := os.Open(e.absPath)
		if err != nil {
			log.Fatal(err)
		}
		if _, err := io.Copy(tw, in); err != nil {
			in.Close()
			log.Fatal(err)
		}
		in.Close()
	}
	if err := tw.Close(); err != nil {
		log.Fatal(err)
	}
	if err := f.Close(); err != nil {
		log.Fatal(err)
	}
	log.Printf("wrote %s (%d bytes, %d entries)", outTar, stSize(outTar), len(entries))
}

func stSize(p string) int64 {
	st, _ := os.Stat(p)
	if st == nil {
		return 0
	}
	return st.Size()
}

