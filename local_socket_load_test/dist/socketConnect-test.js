/******/ (() => { // webpackBootstrap
/******/ 	"use strict";
/******/ 	var __webpack_modules__ = ({

/***/ 966:
/***/ (function(__unused_webpack_module, exports, __webpack_require__) {


var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", ({ value: true }));
var ws_1 = __importDefault(__webpack_require__(727));
var k6_1 = __webpack_require__(392);
exports.default = (function () {
    var socket_url = "wss://shg8k3hoi2.execute-api.ap-northeast-2.amazonaws.com/dev";
    var paramsFromClient = function (num) {
        return {
            headers: { 'clientMessage': "client" + num + "-message" }
        };
    };
    var socket = truckServer();
    var socketRes = socket(socket_url, paramsFromClient(getRandomInt(1, 5)));
    k6_1.check(socketRes, { 'status is 101': function (r) { return r && r.status === 101; } });
});
function truckServer() {
    var socketServer = function (url, params) {
        return ws_1.default.connect(url, params, function (socket) {
            socket.on('open', function () { return console.log('connected'); });
            socket.on('error', function (e) {
                if (e.error() != 'websocket: close sent') {
                    console.log('An unexpected error occured: ', e.error());
                }
            });
            socket.on('message', function (data) { return console.log('Message received: ', data); });
            socket.on('close', function () { return console.log('disconnected'); });
        });
    };
    return socketServer;
}
function getRandomInt(min, max) {
    min = Math.ceil(min);
    max = Math.floor(max);
    return Math.floor(Math.random() * (max - min)) + min; //최댓값은 제외, 최솟값은 포함
}


/***/ }),

/***/ 392:
/***/ ((module) => {

module.exports = require("k6");;

/***/ }),

/***/ 727:
/***/ ((module) => {

module.exports = require("k6/ws");;

/***/ })

/******/ 	});
/************************************************************************/
/******/ 	// The module cache
/******/ 	var __webpack_module_cache__ = {};
/******/ 	
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/ 		// Check if module is in cache
/******/ 		var cachedModule = __webpack_module_cache__[moduleId];
/******/ 		if (cachedModule !== undefined) {
/******/ 			return cachedModule.exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = __webpack_module_cache__[moduleId] = {
/******/ 			// no module.id needed
/******/ 			// no module.loaded needed
/******/ 			exports: {}
/******/ 		};
/******/ 	
/******/ 		// Execute the module function
/******/ 		__webpack_modules__[moduleId].call(module.exports, module, module.exports, __webpack_require__);
/******/ 	
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/ 	
/************************************************************************/
/******/ 	
/******/ 	// startup
/******/ 	// Load entry module and return exports
/******/ 	// This entry module is referenced by other modules so it can't be inlined
/******/ 	var __webpack_exports__ = __webpack_require__(966);
/******/ 	var __webpack_export_target__ = exports;
/******/ 	for(var i in __webpack_exports__) __webpack_export_target__[i] = __webpack_exports__[i];
/******/ 	if(__webpack_exports__.__esModule) Object.defineProperty(__webpack_export_target__, "__esModule", { value: true });
/******/ 	
/******/ })()
;
//# sourceMappingURL=socketConnect-test.js.map