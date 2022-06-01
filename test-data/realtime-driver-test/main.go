package main

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"log"
	"math/rand"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/joho/godotenv"
	jsoniter "github.com/json-iterator/go"
)

const TESTDIR string = "./test_data"

var wg sync.WaitGroup
var json = jsoniter.ConfigCompatibleWithStandardLibrary

type Location struct {
	Lon float64 `json:"lon"`
	Lat float64 `json:"lat"`
}

type TruckLog struct {
	TruckId   uint64 `json:"truckId"`
	TimeStamp uint64 `json:"timestamp"`
	Location  `json:"location"`
}

func (tl *TruckLog) UnmarshalLog(b []byte) error {
	return json.Unmarshal(b, tl)
}

func (tl *TruckLog) MarshalLog() ([]byte, error) {
	return json.Marshal(tl)
}

func main() {
	err := godotenv.Load()
	if err != nil {
		log.Fatal("Error loading .env file")
	}
	serverURL := os.Getenv("SERVER_URL")
	data, err := os.ReadDir(TESTDIR)
	if err != nil {
		log.Fatal("test_data folder missing")
	}
	dirs := len(data)
	wg.Add(dirs)
	for i := 0; i < dirs; i++ {
		dir := TESTDIR + "/" + data[i].Name()
		go func() {
			SendFiles(serverURL, dir)
			wg.Done()
		}()
	}
	wg.Wait()
	log.Println("Send Data Over!")
}

func SendFiles(serverUrl string, dirname string) {
	log.Println("Open Directory :", dirname)
	files, err := os.ReadDir(dirname)
	if err != nil {
		panic(err)
	}
	// fmt.Println("Open files : ", files)
	for _, f := range files {
		var tlog TruckLog
		fileName := dirname + "/" + f.Name()
		fmt.Println("Open file : ", fileName)
		content, err := ioutil.ReadFile(fileName)
		if err != nil {
			panic(err)
		}
		if err := tlog.UnmarshalLog(content); err != nil {
			log.Fatal("JSON encoding Error")
		}
		cbytes, err := tlog.MarshalLog()
		if err != nil {
			log.Fatal("JSON decoding Error")
		}
		buffjson := bytes.NewBuffer(cbytes)
		response, err := http.Post(serverUrl, "application/json", buffjson)
		if err != nil {
			log.Fatal("POST Send Failed")
		}
		resp_success := ((response.StatusCode >= 200) && (response.StatusCode < 400))
		if resp_success {
			time.Sleep(time.Duration((rand.Uint64() * 10) + 30))
		} else {
			log.Fatal("Inproper response")
		}
		log.Println(f.Name() + " Send Successful!")
	}
}
