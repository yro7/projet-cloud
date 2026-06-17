Problem 1 — Spark executors crash, never run distributed
Last WordCount run (4d ago) failed. Both exec pods = Error:


Failed to connect to k8s-master.europe-west9-b.c.project-...internal/<unresolved>:32925
UnknownHostException: k8s-master.europe-west9-b...internal
Cause: 3_run_wordcount.sh:30 runs spark-submit over SSH = client mode. Driver lives on master VM, advertises itself by GCP-internal FQDN. Executor pods inside K3s can't resolve that DNS → can't connect to driver → die. So no real executors = no CPU/mem load ever generated.

Problem 2 — Even if it ran, scrape too slow to see it
scrapeInterval: 30s
WordCount input = people.txt (few lines) → job runs seconds
Executors spawn + die between two scrapes → Prometheus never samples them → Grafana blank
kubectl top / dashboards only show live pods, exec pods already gone
Net: nothing to monitor because job both crashes AND is too small/fast.

Fixes
Fix networking — pin driver to resolvable VPC IP. Add to spark-submit:


--conf spark.driver.host=10.0.1.10 \
--conf spark.driver.bindAddress=0.0.0.0
(10.0.1.10 = master internal IP, reachable by pods in VPC). Cleaner alternative: cluster mode (--deploy-mode cluster) so driver runs as pod, K8s DNS works natively.

Make load visible — pick:

Big input file (100MB+ text) so job runs minutes
Drop scrapeInterval to 5-10s
Force ≥2 executors + keep alive: --conf spark.executor.instances=2 --conf spark.dynamicAllocation.enabled=false
Want me to patch 3_run_wordcount.sh with the driver.host fix + 2 fixed executors + a generated large input file? That gets real visible load on Grafana.

