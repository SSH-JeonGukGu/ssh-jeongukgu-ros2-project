# 팀원 개발환경 세팅 가이드
## Ubuntu Noble + ROS2 Jazzy Docker 환경

---

## 0. 전체 흐름 한눈에 보기

```
[사전 준비]          [저장소 받기]       [환경 실행]           [개발 시작]
Docker 설치    →    git clone     →    방법 선택       →    colcon build
VSCode 설치         (팀 repo)          A) devcontainer       ros2 run ...
                                       B) docker compose
```

---

## 1. 사전 준비 (처음 한 번만)

### Docker Desktop 설치

**Ubuntu (팀원이 Ubuntu를 쓰는 경우)**
```bash
# Docker 공식 GPG 키 추가
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

# Docker 저장소 추가
echo "deb [arch=$(dpkg --print-architecture) \
    signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list

# Docker 설치
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

# sudo 없이 docker 명령어 사용 가능하게 설정 (재로그인 필요)
sudo usermod -aG docker $USER
```

**Windows / macOS**
- https://www.docker.com/products/docker-desktop/ 에서 설치 파일 다운로드 후 실행

### VSCode + Dev Containers 확장 설치

```bash
# VSCode 설치 후 터미널에서 실행
code --install-extension ms-vscode-remote.remote-containers
```
또는 VSCode 확장 탭에서 **"Dev Containers"** 검색 후 설치

---

## 2. 팀 저장소 클론

### 왜 --recurse-submodules가 필요한가

이 저장소는 외부 로봇 패키지(pinky_pro 등)를 **서브모듈(submodule)** 로 관리합니다.

서브모듈이란 팀 repo 안에 외부 repo를 연결해두는 방식입니다.

```
팀 repo
└── src/
    └── pinky_pro/   ← pinklab-art/pinky_pro repo를 연결
```

이렇게 관리하는 이유는 세 가지입니다.

- **버전 고정** — 팀 전체가 pinky_pro의 동일한 커밋을 사용하도록 고정
- **용량 절약** — 외부 패키지 소스를 팀 repo에 직접 복사하지 않아도 됨
- **업데이트 추적** — pinky_pro 원본이 업데이트되면 `git submodule update`로 반영 가능

단, 일반 `git clone`만 하면 **서브모듈 폴더가 빈 채로** 나타납니다.
반드시 아래 방법 중 하나로 clone해야 합니다.

### 클론 방법

**방법 1 — 한 번에 (권장)**
```bash
git clone --recurse-submodules https://github.com/팀org/프로젝트명.git
cd 프로젝트명
```

**방법 2 — 이미 clone한 경우**
```bash
git clone https://github.com/팀org/프로젝트명.git
cd 프로젝트명
git submodule update --init --recursive
```

### 클론 후 폴더 구조 확인

```
프로젝트명/
├── Dockerfile               ← 팀 공통 ROS2 환경 정의
├── docker-compose.yml       ← 컨테이너 실행 설정
├── .gitmodules              ← 서브모듈 URL 정보 (자동 관리)
├── .devcontainer/
│   └── devcontainer.json    ← VSCode 연동 설정
└── src/
    └── pinky_pro/           ← 서브모듈 (내용이 있어야 정상)
```

src/pinky_pro 안에 파일이 있는지 확인:
```bash
ls src/pinky_pro/
# 파일 목록이 나오면 정상
# 비어있으면 → git submodule update --init --recursive 실행
```

### 나중에 서브모듈 업데이트가 필요할 때

팀원으로부터 "pinky_pro 업데이트됐으니 submodule 업데이트 해주세요" 공지를 받으면:
```bash
git pull
git submodule update --recursive
```

---

## 3. 환경 실행 — 방법 A: VSCode Dev Container (권장)

> VSCode가 Docker 빌드/실행을 자동으로 처리해줍니다.
> Docker 명령어를 몰라도 됩니다.

### 3-A-1. VSCode로 폴더 열기
```bash
code .
```

### 3-A-2. 컨테이너로 다시 열기

VSCode 우하단에 팝업이 뜨면:

```
┌─────────────────────────────────────────────┐
│  Folder contains a Dev Container config     │
│  [Reopen in Container]  [Don't show again]  │
└─────────────────────────────────────────────┘
```

**"Reopen in Container"** 클릭

팝업이 없으면: `F1` → `Dev Containers: Reopen in Container` 입력

### 3-A-3. 빌드 대기

처음 실행 시 이미지 빌드가 필요합니다 (5~15분 소요).
우하단에서 진행 상황 확인 가능:

```
[✓] Starting Dev Container (show log)...
```

### 3-A-4. 완료 확인

VSCode 좌하단에 표시가 바뀌면 성공:
```
 Dev Container: ROS2 Jazzy (Ubuntu Noble)
```

터미널 열기 (`Ctrl+` `` ` ``):
```bash
# 아래처럼 표시되면 정상
ros@hostname:/ros2_ws$

# ROS2 동작 확인
echo $ROS_DISTRO
# 출력: jazzy

# 환경변수 확인
echo $ROS_DOMAIN_ID
# 출력: 42
```

---

## 4. 환경 실행 — 방법 B: docker compose (VSCode 없이)

> VSCode를 쓰지 않거나 서버 환경에서 사용할 때 선택합니다.

### 4-0. Docker 데몬 실행 확인 (사전 준비)

**Ubuntu (Docker Engine 설치한 경우)**
```bash
# 실행 상태 확인
sudo systemctl status docker

# 꺼져 있으면 시작
sudo systemctl start docker

# 부팅 시 자동 시작 등록 (처음 한 번만)
sudo systemctl enable docker
```

**Windows / macOS / Ubuntu (Docker Desktop 설치한 경우)**
- Docker Desktop 앱을 먼저 실행
- 트레이 아이콘에 고래 아이콘이 뜨면 준비 완료

데몬 동작 최종 확인:
```bash
docker ps
# 에러 없이 빈 목록이 나오면 정상
```

### 4-1. 프로젝트 폴더로 이동

docker compose 명령은 반드시 **docker-compose.yml이 있는 프로젝트 루트**에서 실행해야 합니다.

```bash
cd ~/ros_ws/프로젝트명
ls
# Dockerfile  docker-compose.yml  .devcontainer/  src/  가 보이면 정상
```

### 4-2. X11 접근 허용 (GUI 앱 실행용, Linux만 해당)

```bash
xhost +local:docker
```

### 4-3. 이미지 빌드 + 컨테이너 실행

```bash
# 처음 실행 (이미지 빌드 포함, 5~15분 소요)
docker compose up -d

# 이후 실행 (이미지가 이미 있으면 빠르게 시작)
docker compose up -d
```

### 4-4. 컨테이너 접속

```bash
docker exec -it pinky_dev bash
```

접속 후 프롬프트:
```bash
ros@hostname:/ros2_ws$
```

### 4-5. 컨테이너 종료

```bash
# 컨테이너에서 나오기 (컨테이너는 계속 실행 중)
exit

# 컨테이너 완전히 종료
docker compose down
```

---

## 5. 개발 시작 — 컨테이너 안에서

### 워크스페이스 빌드

```bash
cd /ros2_ws

# 의존성 설치 (처음 한 번, 또는 새 패키지 추가 후)
rosdep install --from-paths src --ignore-src -y

# 빌드
colcon build --symlink-install

# 빌드 결과 환경 적용
source install/setup.bash
```

### 자주 쓰는 명령어

```bash
# 특정 패키지만 빌드
colcon build --packages-select 패키지명

# RViz2 실행
ros2 run rviz2 rviz2

# 토픽 목록 확인
ros2 topic list

# 노드 실행
ros2 run 패키지명 노드명
```

---

## 6. 로컬 코드 ↔ 컨테이너 동기화

```
내 컴퓨터                    컨테이너
───────────────────────────────────────
프로젝트명/src/  ←──동기화──→  /ros2_ws/src/
```

- 로컬 에디터로 `src/` 안의 파일 수정 → **컨테이너 안에 즉시 반영**
- 컨테이너 안에서 만든 파일도 → **로컬에 즉시 반영**
- `build/`, `install/`, `log/` 폴더는 컨테이너 안에만 존재 (로컬에 없음)

---

## 7. 자주 겪는 문제와 해결법

### RViz2 창이 안 뜰 때 (Linux)

```bash
# 컨테이너 밖 (로컬 터미널)에서 실행
xhost +local:docker

# 컨테이너 안에서 DISPLAY 확인
echo $DISPLAY
# 비어있으면:
export DISPLAY=:0
```

### "permission denied" 오류가 날 때

```bash
# 로컬에서 docker 그룹 추가 후 재로그인
sudo usermod -aG docker $USER
# 터미널 완전히 닫고 다시 열기
```

### Dockerfile이 변경됐다는 팀원 공지를 받았을 때

```bash
# 방법 A (devcontainer): F1 → "Dev Containers: Rebuild Container"

# 방법 B (compose)
docker compose down
docker compose up --build -d
```

### colcon build가 실패할 때

```bash
# 빌드 캐시 초기화 후 재시도
rm -rf build/ install/ log/
colcon build --symlink-install
```

---

## 8. 팀 협업 규칙

| 상황 | 해야 할 일 |
|---|---|
| 새 ROS2 패키지 필요 | `Dockerfile` 수정 후 PR → 팀원들에게 rebuild 공지 |
| 새 패키지 추가 | `src/` 안에 생성 후 git push |
| 빌드 산출물 | `build/`, `install/`, `log/` 는 **절대 git push 하지 않기** (`.gitignore` 처리됨) |
| ROS_DOMAIN_ID | 팀 전체 `42` 고정 (컨테이너 환경변수로 자동 설정) |
