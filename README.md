DevOps-01-Final-TeamA, Scenario 2
=============
[![Resources Applied](https://github.com/cs-devops-bootcamp/devops-01-Final-TeamA-scenario2/actions/workflows/terraform.yml/badge.svg?branch=main&event=push)](https://github.com/cs-devops-bootcamp/devops-01-Final-TeamA-scenario2/actions/workflows/terraform.yml)

Summary
-------------
> 트럭 화물 배달 애플리케이션을 사용하는 사용자들에게,   **화물의 실시간 위치 정보를 제공, 배송 상태를 실시간으로 파악할 수 있게 하는** 서비스 입니다.

Architecture
-------------
![Architecture Pictures](https://user-images.githubusercontent.com/25300991/170899086-7f68fbcb-8509-40f9-b076-cfd9c23891f9.jpeg)

1. Real-time Driver info Data Stream Part (Yellow Part)
   *  실시간으로 들어오는 배송 기사들의 위치 정보 로그는 AWS Kinesis Data Stream에 의해 Streamed Data가 됩니다.
   *  Streamed Data는 AWS Kinesis Firehose에 의해 Opensearch Service의 데이터베이스로 전송되고, 데이터베이스에 로그 데이터들이 쌓입니다.

2. Send driver location info Handling Part (Blue Part)
   * 1분마다 Opensearch Service의 데이터베이스에 질의를 해서 접속된 소비자들과 매칭된 배송 기사들의 최근 위치 정보를 가져와 전송합니다.
   * 접속된 소비자들과 매칭된 배송 기사들 관련 정보는 AWS DynamoDB에 저장합니다.
  
3. Web Socket Connection for Real time connection Part (Red Part)
   * 실시간 데이터 전송을 위해 Web Socket Protocol 연결을 제공하는 서버를 구축합니다.
   * 사용자가 배송 추적 서비스를 사용하기 시작하면, Web Socket의 형태로 서버에 접속되어 실시간으로 매칭된 배송 기사의 위치 정보를 받을 수 있게 됩니다.

How to Use this Application
-------------
### Prerequisites
    * node.js >= 14.0
    * terraform >= 1.0
    * AWS account & AWS CLI
  
1. 다음의 명령어를 통해 해당 저장소의 파일들을 다운받습니다.   

    ```bash 
    $ git clone git@github.com:cs-devops-bootcamp/devops-01-Final-TeamA-scenario2.git
    ```
2. [terraform](https://www.terraform.io/downloads)(없다면 자신의 환경에 맞는 설치파일을 받아 설치합니다.) ```terraform``` 폴더에서 아래의 명령어로 실행. AWS상에 애플리케이션 실행에 필요한 서버와 리소스들을 설치합니다.

    ```bash 
    $ terraform init
    $ terraform apply
    ```

3. 설치된 리소스 중, `API Gateway` 속성 메뉴에서 API Gateway의 `WebSocket URL`과 `Connection URL`을 찾아 `.env` 파일에 기록해둡니다.
   
4. 애플리케이션 실행 준비 끝
5. `local_socket_load_test` 에서 해당 애플리케이션 동작 여부를 테스트해볼 수 있습니다. 테스트 방법은 해당 폴더 `README.md`를 참조하세요