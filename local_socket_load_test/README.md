# How to Use Client Test made by k6

* [이 프로그램은 해당 코드를 참조하여 만들어졌습니다!](https://github.com/grafana/k6-template-typescript)

1. 해당 코드들이 위치한 폴더에서 `npm install` 혹은 `yarn install`로 실행에 필요한 패키지를 설치합니다.

2. `npm run build` 혹은 `yarn webpack`으로 타입스크립트로 작성된 파일들을 컴파일 합니다. 컴파일이 완료되면, 코드가 위치한 폴더 내에 `dist` 폴더가 생성되면서 해당 폴더 안에, 컴파일되어 나온 자바스크립트 파일들이 생성됩니다.

3. `k6 run --vus {접속할 유저 수(정수)} --duration {테스트가 실행될 시간(실수)}s dist/{dist 폴더내에 위치한 자바스크립트 코드 파일 이름, 확장자 포함}` 의 명령어를 입력하면 테스트해볼 수 있습니다.

4. 실행에 있어 다음의 변수들이 정의된 `.env` 파일이 필요합니다.
    * `SOCKET_URL` - WebSocket 접속에 필요한 URL입니다.
    * `GATEWAY_URL` - API Gateway URL입니다.