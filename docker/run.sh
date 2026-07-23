#!/bin/bash
# omx_sim2real runtime — runs the sim<->real bridge on sim_real_bridge_image.
#   run.sh            to_sim  : real arm -> Isaac twin (read-only on real; default)
#   run.sh to_sim     same as above
#   run.sh to_real    Isaac -> real FOLLOWER  (*** MOVES THE REAL ARM ***)
#   run.sh down       stop whichever is running
#
# Bring up the REAL arm separately first (your omx_arm_image tooling), and launch
# Isaac with ROS_DOMAIN_ID=1 + FASTDDS_BUILTIN_TRANSPORTS=UDPv4 (start_isaac_ros.sh).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVF="$SCRIPT_DIR/compose/.env"
tosim=(docker compose --env-file "$ENVF" -f "$SCRIPT_DIR/compose/docker-compose-to_sim.yml")
toreal=(docker compose --env-file "$ENVF" -f "$SCRIPT_DIR/compose/docker-compose-to_real.yml")

case "${1:-to_sim}" in
  to_sim)  "${tosim[@]}" up ;;
  to_real) "${toreal[@]}" up ;;
  down)    "${tosim[@]}" down 2>/dev/null; "${toreal[@]}" down 2>/dev/null ;;
  *)       echo "usage: run.sh [to_sim|to_real|down]"; exit 1 ;;
esac
