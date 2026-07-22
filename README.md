# omx_sim2real

OMX 的 **sim-to-real-to-sim** 機器人資料層,跑在
[`sim_real_bridge_image`](../../docker/sim_real_bridge_image)(不變核心)上。
換機器人時只動這個專案(profile + USD),核心引擎不動——就像
[`omx_teleoperating`](../omx_teleoperating) 對 `omx_arm_image` 的關係。

```
omx_sim2real/
├── profile/
│   ├── omx_l.profile.yaml       # 遙操作端(leader):徒手拖、唯讀 → M1 demo 用這個
│   └── omx_f.profile.yaml       # 跟隨端(follower):框架真正目標
├── assets/
│   ├── omx_f/                   # 從 omx_bringup 匯出的 URDF + meshes(給 Isaac Import)
│   └── omx_f.usd                # 在 Isaac 匯入 + 調好 drive 後 Save 出來的
└── docker/
    ├── compose/{.env, docker-compose-to_sim.yml}
    └── run.sh
```

## 契約回顧

bridge 只認 canonical 關節空間(`JointState`、radians、以關節名為 key),兩端的
單位/topic/sign/offset 全由 `profile/*.profile.yaml` 決定。模式:

| 模式 | 方向 | 動真臂? |
|---|---|---|
| **to_sim**(M1) | 真臂 → Isaac 分身 | 否(唯讀,安全) |
| to_real(M2) | Isaac → 真臂 | 是(先 fake driver 驗) |
| fanout(M3) | 單一命令 → 兩邊同步 | 是 |

## M1 demo:徒手拖 leader,看 Isaac 分身跟著動(唯讀)

**三個終端機**(真臂/bridge 走系統 ROS,都 `ROS_DOMAIN_ID=1`;Isaac 見下):

**① 真臂(leader,torque-off 可徒手拖)** — 用你既有的 omx_arm_image 工具:
```bash
cd .../docker/omx_arm_image
bash scripts/run.sh leader           # 帶起 leader,發布 /leader/joint_states
```

**② Isaac Sim**:用帶環境變數的終端機啟動(`source humble` + `ROS_DOMAIN_ID=1`
+ `FASTDDS_BUILTIN_TRANSPORTS=UDPv4`),載入 `assets/omx_f.usd`,▶ Play。

**③ bridge(to_sim)** — 本專案:
```bash
cd omx_sim2real/docker
bash run.sh                          # 預設 PROFILE=omx_l(見 compose/.env)
```

然後**用手拖動真的 leader 手臂** → Isaac 裡的 omx_f 分身即時跟著動。全程 bridge
只讀 `/leader/joint_states`、寫 `/joint_command`,**不會對真臂下任何命令**。

### 快速自我檢查

```bash
ros2 topic echo /joint_command --once     # 有沒有在發(度數已轉成弧度)
ros2 topic hz  /leader/joint_states       # 真臂有沒有在發狀態
```

## 換成 follower(框架目標)

把 `compose/.env` 的 `PROFILE=omx_l` 改成 `PROFILE=omx_f`,bridge 就改讀
`/follower/joint_states`。但 follower torque-on 會自己 hold,要看到分身動得先讓
follower 動(例如跑 leader→follower 遙操作)。真正「從 sim 驅動 follower」是
**M2(to_real)**,那會動真臂,到時先用 fake driver 驗過再上。

## 連不到?先試這兩個

- **domain 不一致**:三邊(真臂、Isaac、bridge)都要 `ROS_DOMAIN_ID=1`。
- **傳輸**:Isaac / bridge 已強制 `FASTDDS_BUILTIN_TRANSPORTS=UDPv4`;若 bridge
  看不到真臂的 topic,替真臂那邊(omx_arm_image compose)也加上這個 env 再試。
