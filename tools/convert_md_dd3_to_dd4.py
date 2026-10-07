"""Build a DD 4 machine-description entry for the plasmaless circuit model.

Reads the DD3 DINA em_coupling + pf_active and the ITER_MD pf_passive used by
configure_plasmaless_model.m, converts them to DD 4.1.1 and writes:
- em_coupling: the three conductor mutual-inductance matrices as
  coupling_matrix entries (grid matrices are not copied),
- pf_active: coil description only (time-dependent data removed),
- pf_passive: loop description.
The written entry is reread and compared with the DD3 source.
"""

import argparse

import imas
import numpy as np
from imas.util import tree_iter

DD_VERSION = "4.1.1"
DINA_URI = "imas:mdsplus?path=/work/projects/dina/SRO_JINTRAC/15MA_10perc/output"
PF_PASSIVE_URI = "imas:mdsplus?path=/work/imas/shared/imasdb/ITER_MD/3/115005/3"
OUTPUT_URI = "imas:hdf5?path=/scratch/users/schneim/plasmaless/md_dd4"

# name, DD3 field, rows_uri node, columns_uri node
# (rows_uri/columns_uri list every index: the DD validation requires their
# size to match the data dimensions, so the implicit "(:)" form is not used)
MATRICES = [
    (
        "mutual_active_active",
        "mutual_active_active",
        "pf_active/coil",
        "pf_active/coil",
    ),
    (
        "mutual_passive_active",
        "mutual_passive_active",
        "pf_passive/loop",
        "pf_active/coil",
    ),
    (
        "mutual_passive_passive",
        "mutual_passive_passive",
        "pf_passive/loop",
        "pf_passive/loop",
    ),
]


def read_dd3(uri, name):
    with imas.DBEntry(uri, "r") as entry:
        return entry.get(name, autoconvert=False)


def set_properties(ids, comment, sources):
    ids.ids_properties.homogeneous_time = imas.ids_defs.IDS_TIME_MODE_INDEPENDENT
    ids.ids_properties.comment = comment
    ids.ids_properties.provenance.node.resize(1)
    ids.ids_properties.provenance.node[0].path = ""
    ids.ids_properties.provenance.node[0].reference.resize(len(sources))
    for ref, src in zip(ids.ids_properties.provenance.node[0].reference, sources):
        ref.name = src


def build_em_coupling(em3, dina_uri):
    em4 = imas.IDSFactory(DD_VERSION).em_coupling()
    set_properties(
        em4,
        "Conductor mutual inductances (H) copied from the DD3 em_coupling "
        f"mutual_* fields of {dina_uri}",
        [f"{dina_uri}#em_coupling"],
    )
    em4.coupling_matrix.resize(len(MATRICES))
    for cm, (name, field, rows, cols) in zip(em4.coupling_matrix, MATRICES):
        cm.name = name
        cm.quantity.index = 1
        cm.quantity.name = "magnetic_flux"
        cm.quantity.description = "Magnetic flux"
        data = np.array(em3[field])
        cm.rows_uri = [f"{rows}({i + 1})" for i in range(data.shape[0])]
        cm.columns_uri = [f"{cols}({j + 1})" for j in range(data.shape[1])]
        cm.data = data
    return em4


def build_pf_active(pfa3, dina_uri):
    pfa4 = imas.convert_ids(pfa3, DD_VERSION)
    # remove all time-dependent data (coil/supply waveforms, code output, time)
    for node in tree_iter(pfa4, leaf_only=True):
        if node.metadata.type.is_dynamic and node.has_value:
            if node.metadata.ndim == 0:
                raise ValueError(f"Cannot clear dynamic scalar {node.metadata.path}")
            node.value = np.array([], dtype=node.value.dtype)
    set_properties(
        pfa4,
        f"Coil description of {dina_uri} (DD3 pf_active converted to DD "
        f"{DD_VERSION}, time-dependent data removed)",
        [f"{dina_uri}#pf_active"],
    )
    return pfa4


def build_pf_passive(pfp3, pf_passive_uri):
    pfp4 = imas.convert_ids(pfp3, DD_VERSION)
    set_properties(
        pfp4,
        f"Passive loops of {pf_passive_uri} converted to DD {DD_VERSION}",
        [f"{pf_passive_uri}#pf_passive"],
    )
    return pfp4


def check(output_uri, em3, pfa3, pfp3):
    with imas.DBEntry(output_uri, "r") as entry:
        em4 = entry.get("em_coupling")
        pfa4 = entry.get("pf_active")
        pfp4 = entry.get("pf_passive")
    names = [cm.name.value for cm in em4.coupling_matrix]
    for name, field, _, _ in MATRICES:
        data = em4.coupling_matrix[names.index(name)].data
        assert np.array_equal(np.asarray(data), np.asarray(em3[field])), name
    assert len(pfa4.coil) == len(pfa3.coil)
    for c3, c4 in zip(pfa3.coil, pfa4.coil):
        assert c4.name.value == c3.identifier.value, (c4.name, c3.identifier)
        assert c4.resistance.value == c3.resistance.value, c4.name
        assert len(c4.current.data) == 0 and len(c4.voltage.data) == 0
    assert len(pfp4.loop) == len(pfp3.loop)
    for l3, l4 in zip(pfp3.loop, pfp4.loop):
        assert l4.name.value == l3.name.value
        assert l4.resistance.value == l3.resistance.value, l4.name
    print(f"Checked {output_uri} (DD {em4.ids_properties.version_put.data_dictionary})")
    for cm in em4.coupling_matrix:
        print(f"  em_coupling {cm.name.value}: {cm.data.shape}")
    print(f"  pf_active coils: {[c.name.value for c in pfa4.coil]}")
    print(f"  pf_active resistances: {[float(c.resistance) for c in pfa4.coil]}")
    print(f"  pf_passive loops: {len(pfp4.loop)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dina-uri", default=DINA_URI)
    parser.add_argument("--pf-passive-uri", default=PF_PASSIVE_URI)
    parser.add_argument("--output-uri", default=OUTPUT_URI)
    args = parser.parse_args()

    em3 = read_dd3(args.dina_uri, "em_coupling")
    pfa3 = read_dd3(args.dina_uri, "pf_active")
    pfp3 = read_dd3(args.pf_passive_uri, "pf_passive")

    em4 = build_em_coupling(em3, args.dina_uri)
    pfa4 = build_pf_active(pfa3, args.dina_uri)
    pfp4 = build_pf_passive(pfp3, args.pf_passive_uri)

    with imas.DBEntry(args.output_uri, "w", dd_version=DD_VERSION) as entry:
        entry.put(em4)
        entry.put(pfa4)
        entry.put(pfp4)

    check(args.output_uri, em3, pfa3, pfp3)


if __name__ == "__main__":
    main()
