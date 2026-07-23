#!/bin/bash
# omx_sim2real runtime — runs the sim<->real bridge on sim_real_bridge_image.
#   run.sh            to_sim  : real arm -> Isaac twin (read-only on real; default)
#   run.sh to_sim     same as above
#   run.sh to_real    Isaac -> real FOLLOWER            (*** MOVES THE REAL ARM ***)
#   run.sh fanout     /sync/command -> BOTH sim + real  (*** MOVES THE REAL ARM ***)
#   run.sh lead       hand-drag LEADER -> BOTH sim + follower, direct  (*** MOVES ARM ***)
#   run.sh lead-chain hand-drag LEADER -> sim -> follower, via Isaac   (*** MOVES ARM ***)
#   run.sh monitor    read-only sim<->real divergence report (safe; runs alongside)
#   run.sh down       stop everything
#
# Bring up the REAL arm separately first (your omx_arm_image tooling), and launch
# Isaac with ROS_DOMAIN_ID=1 + FASTDDS_BUILTIN_TRANSPORTS=UDPv4 (start_isaac_ros.sh).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVF="$SCRIPT_DIR/compose/.env"

compose() {  # compose <mode> <docker-compose args...>
  docker compose --env-file "$ENVF" \
    -f "$SCRIPT_DIR/compose/docker-compose-$1.yml" "${@:2}"
}

case "${1:-to_sim}" in
  to_sim)     compose to_sim  up ;;
  to_real)    compose to_real up ;;
  fanout)     compose fanout  up ;;
  lead)       compose lead    up ;;
  lead-chain) compose lead-chain up ;;
  monitor)    compose monitor run --rm monitor ;;   # interactive TTY for the curses TUI
  down)       for m in to_sim to_real fanout lead lead-chain monitor; do
                compose "$m" down 2>/dev/null; done ;;
  *)          echo "usage: run.sh [to_sim|to_real|fanout|lead|lead-chain|monitor|down]"; exit 1 ;;
esac
