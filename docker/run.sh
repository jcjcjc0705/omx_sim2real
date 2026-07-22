#!/bin/bash
# omx_sim2real runtime — runs the sim<->real bridge on sim_real_bridge_image.
#   run.sh            start the bridge (to_sim) in the foreground (Ctrl+C to stop)
#   run.sh down       stop / clean up
#   run.sh <args...>  passthrough to `docker compose`
#
# Bring up the REAL arm separately first (your omx_arm_image tooling), and launch
# Isaac Sim with ROS_DOMAIN_ID=1 + FASTDDS_BUILTIN_TRANSPORTS=UDPv4.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE=(docker compose --env-file "$SCRIPT_DIR/compose/.env"
         -f "$SCRIPT_DIR/compose/docker-compose-to_sim.yml")

case "${1:-up}" in
  up|"") "${COMPOSE[@]}" up ;;
  down)  "${COMPOSE[@]}" down ;;
  *)     "${COMPOSE[@]}" "$@" ;;
esac
