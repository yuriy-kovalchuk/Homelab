#!/usr/bin/env python3
"""Load homelab.yaml into NetBox. Safe to re-run: each object is looked up by
its natural key and only created or updated when it differs. Nothing is ever
deleted — remove objects from NetBox by hand.

Usage:
  NETBOX_URL=https://netbox.yuriykovalchuk.dev \
  NETBOX_AUTH_HEADER="Bearer nbt_<key>.<token>" \
  python netbox/sync.py [--dry-run]

Needs pynetbox and PyYAML.
"""
import os
import re
import sys
from pathlib import Path

import pynetbox
import yaml

DRY = "--dry-run" in sys.argv
data = yaml.safe_load((Path(__file__).parent / "homelab.yaml").read_text())

nb = pynetbox.api(os.environ.get("NETBOX_URL", "https://netbox.yuriykovalchuk.dev"))
# NetBox 4.7 v2 tokens use "Bearer nbt_…", which pynetbox's token argument doesn't build
nb.http_session.headers["Authorization"] = os.environ["NETBOX_AUTH_HEADER"]

stats = {"created": 0, "updated": 0, "unchanged": 0}


def slugify(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def _norm(v):
    if isinstance(v, dict):
        return v.get("id", v.get("value", v))
    if isinstance(v, list):
        return sorted((_norm(x) for x in v), key=lambda x: (x is None, str(x)))  # None: not created yet (dry run)
    return v


def ensure(endpoint, lookup, fields=None, label=None):
    """Return the object matching `lookup`, creating it or fixing `fields`."""
    fields = fields or {}
    label = label or f"{endpoint.name} {lookup}"
    obj = endpoint.get(**lookup)
    if obj is None:
        stats["created"] += 1
        print(f"  + {label}")
        if DRY:
            return None
        return endpoint.create({**lookup, **fields})
    current = obj.serialize()
    diff = {k: v for k, v in fields.items() if _norm(current.get(k)) != _norm(v)}
    if diff:
        stats["updated"] += 1
        print(f"  ~ {label}: {', '.join(diff)}")
        if not DRY:
            obj.update(diff)
            obj = endpoint.get(obj.id)
    else:
        stats["unchanged"] += 1
    return obj


def oid(obj):
    return obj.id if obj is not None else None


print("Organization")
site = ensure(nb.dcim.sites, {"slug": data["site"]["slug"]}, {"name": data["site"]["name"], "status": "active"})
tags = {t["name"]: ensure(nb.extras.tags, {"slug": slugify(t["name"])},
                          {"name": t["name"], "color": t["color"], "description": t["description"]})
        for t in data["tags"]}

print("Device catalogue")
mfr = {m: ensure(nb.dcim.manufacturers, {"slug": slugify(m)}, {"name": m}) for m in data["manufacturers"]}
roles = {r["slug"]: ensure(nb.dcim.device_roles, {"slug": r["slug"]},
                           {"name": r["name"], "color": r["color"], "vm_role": True})
         for r in data["device_roles"]}
platforms = {p["slug"]: ensure(nb.dcim.platforms, {"slug": p["slug"]}, {"name": p["name"]}) for p in data["platforms"]}
dtypes = {t["slug"]: ensure(nb.dcim.device_types, {"slug": t["slug"]},
                            {"model": t["model"], "manufacturer": oid(mfr[t["manufacturer"]])})
          for t in data["device_types"]}

print("VLANs and IP space")
vlans = {v["vid"]: ensure(nb.ipam.vlans, {"vid": v["vid"], "site_id": oid(site)},
                          {"name": v["name"], "description": v["description"], "status": "active", "site": oid(site)},
                          label=f"vlan {v['vid']}")
         for v in data["vlans"]}
for p in data["prefixes"]:
    f = {"status": p.get("status", "active"), "description": p["description"],
         "scope_type": "dcim.site", "scope_id": oid(site)}
    if "vlan" in p:
        f["vlan"] = oid(vlans[p["vlan"]])
    ensure(nb.ipam.prefixes, {"prefix": p["prefix"]}, f, label=f"prefix {p['prefix']}")
for r in data["ip_ranges"]:
    ensure(nb.ipam.ip_ranges, {"start_address": r["start"]},
           {"end_address": r["end"], "status": r.get("status", "active"), "description": r["description"]},
           label=f"range {r['start']}–{r['end']}")
for ip in data["standalone_ips"]:
    ensure(nb.ipam.ip_addresses, {"address": ip["address"]},
           {"dns_name": ip.get("dns_name", ""), "description": ip["description"], "status": "active"},
           label=f"ip {ip['address']}")

print("Clusters")
ctypes = {}
clusters = {}
for c in data["clusters"]:
    t = c["type"]
    ctypes.setdefault(t, ensure(nb.virtualization.cluster_types, {"slug": slugify(t)}, {"name": t}))
    clusters[c["name"]] = ensure(nb.virtualization.clusters, {"name": c["name"]},
                                 {"type": oid(ctypes[t]), "status": "active", "description": c.get("description", ""),
                                  "scope_type": "dcim.site", "scope_id": oid(site)},
                                 label=f"cluster {c['name']}")
host_cluster = {c["device"]: clusters[c["name"]] for c in data["clusters"] if "device" in c}


def ensure_mac(mac, obj_type, iface):
    m = ensure(nb.dcim.mac_addresses, {"mac_address": mac.upper()},
               {"assigned_object_type": obj_type, "assigned_object_id": oid(iface)}, label=f"mac {mac}")
    return m


def ensure_ips(ip_list, obj_type, iface, dns_name):
    created = []
    for entry in ip_list or []:
        e = entry if isinstance(entry, dict) else {"address": entry}
        f = {"assigned_object_type": obj_type, "assigned_object_id": oid(iface), "status": "active",
             "description": e.get("description", "")}
        if e.get("role"):
            f["role"] = e["role"]
        elif dns_name:
            f["dns_name"] = dns_name
        created.append(ensure(nb.ipam.ip_addresses, {"address": e["address"]}, f, label=f"ip {e['address']}"))
    return created


def vlan_fields(i):
    f = {}
    if i.get("mode"):
        f["mode"] = i["mode"]
    if "untagged_vlan" in i:
        f["untagged_vlan"] = oid(vlans[i["untagged_vlan"]])
    if "tagged_vlans" in i:
        f["tagged_vlans"] = [oid(vlans[v]) for v in i["tagged_vlans"]]
    return f


print("Devices")
ifaces = {}
for d in data["devices"]:
    f = {"device_type": oid(dtypes[d["type"]]), "role": oid(roles[d["role"]]), "site": oid(site),
         "status": d.get("status", "active"), "description": d.get("description", ""),
         "comments": d.get("comments", ""), "tags": [oid(tags[t]) for t in d.get("tags", [])]}
    if d.get("platform"):
        f["platform"] = oid(platforms[d["platform"]])
    cl = clusters.get(d.get("cluster")) or host_cluster.get(d["name"])
    if cl:
        f["cluster"] = oid(cl)
    dev = ensure(nb.dcim.devices, {"name": d["name"]}, f, label=f"device {d['name']}")
    if dev is None:
        continue
    primary = None
    for i in d.get("interfaces", []):
        fi = {"type": i["type"], "description": i.get("description", ""), "enabled": i.get("enabled", True),
              **vlan_fields(i)}
        iface = ensure(nb.dcim.interfaces, {"device_id": dev.id, "name": i["name"]},
                       {**fi, "device": dev.id}, label=f"{d['name']}/{i['name']}")
        ifaces[f"{d['name']}/{i['name']}"] = iface
        if iface is None:
            continue
        if i.get("mac"):
            m = ensure_mac(i["mac"], "dcim.interface", iface)
            ensure(nb.dcim.interfaces, {"id": iface.id}, {"primary_mac_address": oid(m)}, label=f"{d['name']}/{i['name']} mac")
        ips = ensure_ips(i.get("ips"), "dcim.interface", iface, d["name"] if i.get("primary") else "")
        if i.get("primary") and ips:
            primary = ips[0]
    for i in d.get("interfaces", []):
        for member in i.get("bridge_members", []):
            ensure(nb.dcim.interfaces, {"id": oid(ifaces[f"{d['name']}/{member}"])},
                   {"bridge": oid(ifaces[f"{d['name']}/{i['name']}"])}, label=f"{d['name']}/{member} → {i['name']}")
    if primary is not None:
        ensure(nb.dcim.devices, {"id": dev.id}, {"primary_ip4": primary.id}, label=f"device {d['name']} primary ip")
    for item in d.get("inventory", []):
        ensure(nb.dcim.inventory_items, {"device_id": dev.id, "name": item["name"]},
               {"device": dev.id, "manufacturer": oid(mfr[item["manufacturer"]]), "part_id": item["part_id"],
                "description": item["description"]}, label=f"{d['name']} inventory {item['name']}")

print("Cables")
for a, b in data["cables"]:
    ia, ib = ifaces.get(a), ifaces.get(b)
    if ia is None or ib is None:
        print(f"  ! skip {a} ↔ {b} (interface missing)")
        continue
    if nb.dcim.interfaces.get(ia.id).cable is not None:
        stats["unchanged"] += 1
        continue
    stats["created"] += 1
    print(f"  + cable {a} ↔ {b}")
    if not DRY:
        nb.dcim.cables.create({"a_terminations": [{"object_type": "dcim.interface", "object_id": ia.id}],
                               "b_terminations": [{"object_type": "dcim.interface", "object_id": ib.id}],
                               "status": "connected"})

print("Virtual machines")
for v in data["virtual_machines"]:
    cl = clusters[v["cluster"]]
    host = next((c["device"] for c in data["clusters"] if c["name"] == v["cluster"]), None)
    f = {"cluster": oid(cl), "site": oid(site), "status": "active", "vcpus": v["vcpus"], "memory": v["memory"],
         "disk": v["disk"] * 1000, "description": v["description"], "platform": oid(platforms[v["platform"]])}
    if host:
        f["device"] = oid(nb.dcim.devices.get(name=host))
    if v.get("role"):
        f["role"] = oid(roles[v["role"]])
    vm = ensure(nb.virtualization.virtual_machines, {"name": v["name"]}, f, label=f"vm {v['name']}")
    if vm is None:
        continue
    vmifaces, primary = {}, None
    for i in v["interfaces"]:
        fi = {"description": i.get("description", ""), **vlan_fields(i), "virtual_machine": vm.id}
        if i.get("parent"):
            fi["parent"] = oid(vmifaces[i["parent"]])
        iface = ensure(nb.virtualization.interfaces, {"virtual_machine_id": vm.id, "name": i["name"]}, fi,
                       label=f"{v['name']}/{i['name']}")
        vmifaces[i["name"]] = iface
        if iface is None:
            continue
        if i.get("mac"):
            m = ensure_mac(i["mac"], "virtualization.vminterface", iface)
            ensure(nb.virtualization.interfaces, {"id": iface.id}, {"primary_mac_address": oid(m)},
                   label=f"{v['name']}/{i['name']} mac")
        ips = ensure_ips(i.get("ips"), "virtualization.vminterface", iface, v["name"] if i.get("primary") else "")
        if i.get("primary") and ips:
            primary = ips[0]
    if primary is not None:
        ensure(nb.virtualization.virtual_machines, {"id": vm.id}, {"primary_ip4": primary.id}, label=f"vm {v['name']} primary ip")

print(f"\n{'DRY RUN — ' if DRY else ''}created {stats['created']}, updated {stats['updated']}, unchanged {stats['unchanged']}")
