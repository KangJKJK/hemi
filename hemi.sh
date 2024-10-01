#!/bin/bash

# 색상 변수 정의
RED='\033[1;31m'   # 빨강
GREEN='\033[1;32m' # 초록
YELLOW='\033[1;33m' # 노랑
BLUE='\033[1;34m'  # 파랑
PURPLE='\033[1;35m' # 보라
CYAN='\033[1;36m'  # 하늘
NC='\033[0m'       # 색상 초기화

# 시스템 아키텍처 확인
ARCH=$(uname -m)

# 메시지 출력 함수 (색상 적용)
show() {
    case $2 in
        "빨강") COLOR="$RED" ;;
        "초록") COLOR="$GREEN" ;;
        "노랑") COLOR="$YELLOW" ;;
        "파랑") COLOR="$BLUE" ;;
        "보라") COLOR="$PURPLE" ;;
        "하늘") COLOR="$CYAN" ;;
        *) COLOR="$NC" ;;
    esac
    echo -e "${COLOR}$1${NC}"
}

# jq 설치 여부 확인
if ! command -v jq &> /dev/null; then
    show "jq가 설치되지 않았습니다. 설치를 시작합니다..." "노랑"
    sudo apt-get update
    sudo apt-get install -y jq > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        show "jq 설치 실패. 패키지 매니저를 확인하세요." "빨강"
        exit 1
    fi
fi

# GitHub에서 최신 버전 확인 함수
check_latest_version() {
    for i in {1..3}; do
        LATEST_VERSION=$(curl -s https://api.github.com/repos/hemilabs/heminetwork/releases/latest | jq -r '.tag_name')
        if [ -n "$LATEST_VERSION" ]; then
            show "사용 가능한 최신 버전: $LATEST_VERSION" "초록"
            return 0
        fi
        show "시도 $i: 최신 버전 정보를 가져오는 데 실패했습니다. 다시 시도 중..." "노랑"
        sleep 2
    done

    show "3번의 시도 후 최신 버전을 가져오는 데 실패했습니다. 인터넷 연결 또는 GitHub API 제한을 확인하세요." "빨강"
    exit 1
}

# 최신 버전 확인 호출
check_latest_version

# 다운로드 여부 플래그 설정
download_required=true

# 아키텍처에 따라 다운로드 경로 설정
if [ "$ARCH" == "x86_64" ]; then
    if [ -d "heminetwork_${LATEST_VERSION}_linux_amd64" ]; then
        show "x86_64 용 최신 버전이 이미 다운로드되었습니다. 다운로드를 건너뜁니다." "초록"
        cd "heminetwork_${LATEST_VERSION}_linux_amd64" || { show "디렉토리 변경 실패." "빨강"; exit 1; }
        download_required=false  # 다운로드 필요 없음
    fi
elif [ "$ARCH" == "arm64" ]; then
    if [ -d "heminetwork_${LATEST_VERSION}_linux_arm64" ]; then
        show "arm64 용 최신 버전이 이미 다운로드되었습니다. 다운로드를 건너뜁니다." "초록"
        cd "heminetwork_${LATEST_VERSION}_linux_arm64" || { show "디렉토리 변경 실패." "빨강"; exit 1; }
        download_required=false  # 다운로드 필요 없음
    fi
fi

# 다운로드 필요 시 실행
if [ "$download_required" = true ]; then
    if [ "$ARCH" == "x86_64" ]; then
        show "x86_64 아키텍처에 맞는 파일을 다운로드 중..." "파랑"
        wget --quiet --show-progress "https://github.com/hemilabs/heminetwork/releases/download/$LATEST_VERSION/heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz" -O "heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz"
        tar -xzf "heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz" > /dev/null
        cd "heminetwork_${LATEST_VERSION}_linux_amd64" || { show "디렉토리 변경 실패." "빨강"; exit 1; }
    elif [ "$ARCH" == "arm64" ]; then
        show "arm64 아키텍처에 맞는 파일을 다운로드 중..." "파랑"
        wget --quiet --show-progress "https://github.com/hemilabs/heminetwork/releases/download/$LATEST_VERSION/heminetwork_${LATEST_VERSION}_linux_arm64.tar.gz" -O "heminetwork_${LATEST_VERSION}_linux_arm64.tar.gz"
        tar -xzf "heminetwork_${LATEST_VERSION}_linux_arm64.tar.gz" > /dev/null
        cd "heminetwork_${LATEST_VERSION}_linux_arm64" || { show "디렉토리 변경 실패." "빨강"; exit 1; }
    else
        show "지원되지 않는 아키텍처: $ARCH" "빨강"
        exit 1
    fi
else
    show "최신 버전이 이미 존재하므로 다운로드를 건너뜁니다." "하늘"
fi

# 옵션 선택 안내
echo
show "하나의 옵션만 선택하세요:" "노랑"
show "1. PoP 마이닝을 위한 새 지갑 사용" "초록"
show "2. PoP 마이닝을 위한 기존 지갑 사용" "초록"
read -p "선택하세요 (1/2): " choice
echo

# 선택한 옵션에 따라 지갑 생성 또는 기존 지갑 사용
if [ "$choice" == "1" ]; then
    show "새 지갑을 생성 중..." "파랑"
    ./keygen -secp256k1 -json -net="testnet" > ~/popm-address.json
    if [ $? -ne 0 ]; then
        show "지갑 생성에 실패했습니다." "빨강"
        exit 1
    fi
    cat ~/popm-address.json
    echo
    read -p "위 정보를 저장하셨습니까? (y/N): " saved
    echo
    if [[ "$saved" =~ ^[Yy]$ ]]; then
        pubkey_hash=$(jq -r '.pubkey_hash' ~/popm-address.json)
        show "참여하기: https://discord.gg/hemixyz" "보라"
        show "이 주소로 faucet 채널에서 요청하세요: $pubkey_hash" "보라"
        echo
        read -p "faucet을 요청하셨습니까? (y/N): " faucet_requested
        if [[ "$faucet_requested" =~ ^[Yy]$ ]]; then
            priv_key=$(jq -r '.private_key' ~/popm-address.json)
            read -p "고정 수수료 입력 (숫자만, 권장: 100-200): " static_fee
            echo
        fi
    fi

elif [ "$choice" == "2" ]; then
    read -p "프라이빗 키를 입력하세요: " priv_key
    read -p "고정 수수료 입력 (숫자만, 권장: 100-200): " static_fee
    echo
fi

# hemi.service 상태 확인 및 제어
if systemctl is-active --quiet hemi.service; then
    show "hemi.service가 실행 중입니다. 중지 및 비활성화 중..." "노랑"
    sudo systemctl stop hemi.service
    sudo systemctl disable hemi.service
else
    show "hemi.service가 실행 중이지 않습니다." "하늘"
fi

# 새로운 hemi 서비스 파일 작성
cat << EOF | sudo tee /etc/systemd/system/hemi.service > /dev/null
[Unit]
Description=Hemi Network popmd 서비스
After=network.target

[Service]
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/popmd
Environment="POPM_BTC_PRIVKEY=$priv_key"
Environment="POPM_STATIC_FEE=$static_fee"
Environment="POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# systemd 데몬 재로드 및 서비스 시작
sudo systemctl daemon-reload
sudo systemctl enable hemi.service
sudo systemctl start hemi.service
echo
show "PoP 마이닝이 성공적으로 시작되었습니다." "초록"

cat ~/popm-address.json
read -p "위에 표시되는 내용을 따로 저장한 후 엔터를 눌러주세요."

echo -e "${GREEN}모든 작업이 완료되었습니다. 컨트롤+A+D로 스크린을 분리해주세요.${NC}"
echo -e "${RED}다음 명령어로 로그를 확인하세요: sudo journalctl -u hemi.service -f -n 50 ${NC}"
echo -e "${GREEN}스크립트작성자-https://t.me/kjkresearch${NC}"
