package main

import (
	"bytes"
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
const MIN_SEC int = 5
const INTERVAL int = 40

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
	log.Printf("[%s] <- Open Directory\n", dirname)
	files, err := os.ReadDir(dirname)
	if err != nil {
		panic(err)
	}
	// fmt.Println("Open files : ", files)
	for _, f := range files {
		var tlog TruckLog
		fileName := dirname + "/" + f.Name()
		log.Printf("[%s] <- Open file\n", f.Name())
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
		defer response.Body.Close()
		resp_success := ((response.StatusCode >= 200) && (response.StatusCode < 400))
		if resp_success {
			log.Printf("[%s] <- Sent Successful!\n", f.Name())
			rand.Seed(time.Now().UnixNano())
			sleepTime := MIN_SEC + rand.Intn(INTERVAL)
			log.Printf("Moving...%ds\n", sleepTime)
			time.Sleep(time.Second * time.Duration(sleepTime))
		} else {
			log.Fatalf("[%s] <- Send Failed and Program will be terminated\n", f.Name())
		}

	}
}
