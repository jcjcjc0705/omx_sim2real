# omx_sim2real

OMX 的 **sim-to-real-to-sim** 機器人資料層,跑在
[`sim_real_bridge_image`](../../docker/sim_real_bridge_image)(不變核心)上。
換機器人時只動這個專案(profile + USD),核心引擎不動——就像
[`omx_teleoperating`](../omx_teleoperating) 對 `omx_arm_image` 的關係。

```
omx_sim2real/
├── profile/
│   ├── omx_l.profile.yaml   # leader(遙操作端,徒手拖)
│   └── omx_f.profile.yaml   # follower(框架目標)
├── assets/
│   ├── omx_f/               # 從 omx_bringup 匯出的 URDF + meshes(給 Isaac Import)
│   └── omx_f.usd            # Isaac 匯入 + 調好 drive + Action Graph 後 Save 出來的
└── docker/
    ├── compose/.env
    ├── compose/docker-compose-{to_sim,to_real,fanout,lead,lead-chain,monitor}.yml
    └── run.sh
```

## 契約 / 校正

bridge 只認 canonical 關節空間(`JointState`、radians、以關節名為 key)。
**canonical = 真臂 driver 慣例(弧度)**,所以 real 端是純 deg↔rad(恆等),所有
「USD 零位/軸向對不上」的校正(sign/offset)放 `sim.per_joint`。OMX 實測校正:

- DYNAMIXEL 位置模式**中心在 180°** → 每軸 `offset = -π`
- follower 六軸都 `sign +1`
- leader gripper `sign -1`(跟 follower 夾爪鏡像;follower gripper 是 `+1`)

## 模式(`run.sh <mode>`)

| 指令 | 方向 | 需要的真臂 | 動真臂? |
|---|---|---|---|
| `run.sh`(= to_sim) | 真臂 → Isaac 分身 | leader(見 .env PROFILE) | 否(唯讀) |
| `run.sh to_real` | Isaac → 真 follower | follower | **是** |
| `run.sh fanout` | `/sync/command` → sim+real 同步 | follower | **是** |
| `run.sh lead` | 徒手拖 leader → sim + follower(**直接**,低延遲) | leader + follower | **是** |
| `run.sh lead-chain` | leader → sim → follower(經 Isaac,sim 當碰撞過濾) | leader + follower | **是** |
| `run.sh monitor` | leader/follower/sim **三欄偏差 TUI**(唯讀,可與任何模式併跑) | — | 否 |
| `run.sh down` | 停掉全部 | — | — |

## 前置(每次)

1. **真臂**:用 `omx_arm_image` 的 `scripts/run.sh leader` / `run.sh follower`
   (看模式需要哪隻;lead* 需要**兩隻**)。
2. **Isaac**:`~/Desktop/isaac_sim_5.1/start_isaac_ros.sh` 啟動(帶 `ROS_DOMAIN_ID=1`
   + `FASTDDS_BUILTIN_TRANSPORTS=UDPv4`)→ 載 `assets/omx_f.usd` → Action Graph
   (`Subscribe /joint_command` + `Publish /joint_states`,`targetPrim = root_joint`)→ ▶ Play。
3. 每個終端機都要 `ROS_DOMAIN_ID=1` + `FASTDDS_BUILTIN_TRANSPORTS=UDPv4`
   (建議寫進 `~/.bashrc`)。

## 最完整的 demo:leader 同時控制 sim + follower

```bash
(omx_arm_image) bash scripts/run.sh leader     # 來源(torque off,可拖)
(omx_arm_image) bash scripts/run.sh follower   # 目標(torque on)
                bash run.sh lead               # bridge:leader → sim + follower
                bash run.sh monitor            # 另開:三欄看 leader≈follower≈sim
```
徒手拖 leader → Isaac 分身 + 真 follower 一起動。monitor 的 `spread` / 兩兩偏差
超過 5° 的那格會標紅。

## 安全

- **to_sim / monitor**:唯讀,安全。
- **to_real / fanout / lead / lead-chain**:會動真 follower → **先讓 sim≈real 起步、
  手放 Ctrl+C、小步試**。
- ⚠️ 這份 URDF 限位是全開的 ±360°,**擋不住真臂**;耦合的自我碰撞安全夾限**尚未做**(TODO)。

## 動不了 / 連不到?

- 先 `docker ps` + `ros2 topic list`。若只有 `/joint_command`、`/joint_states`
  (Isaac 的)而**沒有** `/leader/joint_states`、`/follower/joint_states` → **真臂沒 bring up**。
- 三邊(真臂、Isaac、bridge)`ROS_DOMAIN_ID` 都要 `1`,都要 UDPv4。
- 殘留 bridge 打架 → `bash run.sh down` 清掉(orphan 警告無害)。
- 真臂完全不回應(有命令卻不動)→ 可能 DYNAMIXEL Hardware Error,進 follower container
  `dxl_cli.py READ <id>` 看錯、`REBOOT <id>` 清。
