# ============================================================
# 베이스 이미지
# ============================================================
# OSRF(Open Source Robotics Foundation)에서 공식 제공하는 이미지
# jazzy-desktop-full = Ubuntu 24.04 Noble + ROS2 Jazzy + RViz2 + Gazebo 포함
FROM osrf/ros:jazzy-desktop-full

# ============================================================
# 빌드 인자 (팀원마다 다를 수 있는 값을 변수로 관리)
# ============================================================
ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=1000

# ============================================================
# Gazebo Harmonic apt 저장소 등록
# ============================================================
# libgz-sim8-dev, libgz-plugin2-dev 등은 Ubuntu 기본 저장소에 없고
# OSRF의 packages.osrfoundation.org 에서 제공됨
RUN apt-get update && apt-get install -y curl gnupg lsb-release \
    && curl -fsSL https://packages.osrfoundation.org/gazebo.gpg \
        -o /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) \
        signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] \
        http://packages.osrfoundation.org/gazebo/ubuntu-stable \
        $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/gazebo-stable.list \
    && rm -rf /var/lib/apt/lists/*
    
# ============================================================
# 시스템 패키지 업데이트 및 개발 도구 설치
# ============================================================
RUN apt-get update && apt-get install -y \
    # 기본 개발 도구
    git \
    wget \
    curl \
    vim \
    build-essential \
    cmake \
    # Python 도구
    python3-pip \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-vcstool \
    # ROS2 공통 패키지
    ros-jazzy-navigation2 \
    ros-jazzy-nav2-bringup \
    ros-jazzy-slam-toolbox \
    ros-jazzy-ros2-control \
    ros-jazzy-ros2-controllers \
    ros-jazzy-joint-state-publisher \
    ros-jazzy-joint-state-publisher-gui \
    ros-jazzy-xacro \
    ros-jazzy-robot-state-publisher \
    # Gazebo Harmonic <-> ROS2 Jazzy 브리지
    # pinky_gz_sim 빌드에 필요한 ros_gz 패키지들
    ros-jazzy-ros-gz \
    ros-jazzy-ros-gz-bridge \
    ros-jazzy-ros-gz-sim \
    ros-jazzy-ros-gz-image \
    ros-jazzy-ros-gz-interfaces \
    # find_package(gz_ros2_control) 대응
    ros-jazzy-gz-ros2-control \
    # find_package(gz-sim8), find_package(gz-plugin2) 대응
    # Gazebo Harmonic 코어 라이브러리 (ros 패키지가 아닌 gz 패키지)
    libgz-sim8-dev \
    libgz-plugin2-dev \
    # 네트워크/디버깅 도구
    iproute2 \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*   # 캐시 삭제 → 이미지 크기 감소

# ============================================================
# rosdep 초기화
# ============================================================
# rosdep: 패키지 의존성 자동 설치 도구
RUN rosdep update

# ============================================================
# 비root 사용자 생성 (보안 및 파일 권한 문제 방지)
# ============================================================
# osrf/ros 베이스 이미지에 ubuntu 그룹(GID 1000)이 이미 존재하므로
# 중복 생성 시도 시 오류가 발생함 → 존재 여부를 먼저 확인 후 처리
RUN apt-get update && apt-get install -y sudo \
    && rm -rf /var/lib/apt/lists/* \
    # GID가 이미 존재하면 해당 그룹명을 $USERNAME으로 변경, 없으면 새로 생성
    && if getent group $USER_GID > /dev/null 2>&1; then \
         groupmod -n $USERNAME $(getent group $USER_GID | cut -d: -f1); \
       else \
         groupadd --gid $USER_GID $USERNAME; \
       fi \
    # UID가 이미 존재하면 해당 유저명을 $USERNAME으로 변경, 없으면 새로 생성
    && if getent passwd $USER_UID > /dev/null 2>&1; then \
         usermod -l $USERNAME -d /home/$USERNAME -m \
             $(getent passwd $USER_UID | cut -d: -f1); \
       else \
         useradd --uid $USER_UID --gid $USER_GID -m $USERNAME; \
       fi \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ============================================================
# 작업 디렉토리 및 사용자 전환
# ============================================================
WORKDIR /ros2_ws
RUN chown -R $USERNAME:$USERNAME /ros2_ws
USER $USERNAME

# ============================================================
# ROS2 환경 자동 source 설정
# ============================================================
# 컨테이너에서 터미널 열 때마다 수동으로 source 하지 않아도 됨
RUN echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc \
    && echo "source /ros2_ws/install/setup.bash 2>/dev/null || true" >> ~/.bashrc \
    # colcon 빌드 결과 자동 source (빌드 전에는 오류 무시)
    && echo "export ROS_DOMAIN_ID=42" >> ~/.bashrc \
    && echo "export ROS_LOCALHOST_ONLY=0" >> ~/.bashrc

# ============================================================
# 컨테이너 시작 시 실행할 기본 명령
# ============================================================
# bash 셸로 진입 (대화형 개발 환경)
CMD ["/bin/bash"]
