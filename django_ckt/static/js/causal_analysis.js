/**
 * Causal Analysis tab — fetches analysis from the currently selected graph.
 */
(function () {
    'use strict';

    var allVariables = [];

    function show(id) { document.getElementById(id).style.display = ''; }
    function hide(id) { document.getElementById(id).style.display = 'none'; }
    function setText(id, v) { document.getElementById(id).textContent = v; }

    function apiGet(url) {
        return fetch(url).then(function (r) { return r.json(); });
    }
    function apiPost(url, body) {
        return fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'X-CSRFToken': csrfToken },
            body: JSON.stringify(body),
        }).then(function (r) { return r.json(); });
    }

    // ── populate summary cards ──
    function renderSummary(d) {
        setText('acNodes', d.node_count);
        setText('acEdges', d.edge_count);
        setText('acDensity', d.density.toFixed(6));
        setText('acCycles', d.cycle_count + ' (' + d.cycle_node_count + ' nodes)');
        setText('filenameLabel', d.filename);

        // predicate table
        var tbody = document.querySelector('#predicateTable tbody');
        tbody.innerHTML = '';
        var preds = Object.entries(d.predicate_distribution || {}).sort(function (a, b) { return b[1] - a[1]; });
        preds.forEach(function (p) {
            var tr = document.createElement('tr');
            tr.innerHTML = '<td>' + p[0] + '</td><td class="text-end">' + p[1] + '</td>';
            tbody.appendChild(tr);
        });

        // top nodes table
        var tbody2 = document.querySelector('#topNodesTable tbody');
        tbody2.innerHTML = '';
        (d.top_nodes || []).forEach(function (n) {
            var tr = document.createElement('tr');
            tr.innerHTML = '<td>' + n.id.replace(/_/g, ' ') + '</td><td class="text-end">' + n.degree + '</td>';
            tbody2.appendChild(tr);
        });
    }

    // ── populate variable dropdowns ──
    function populateDropdowns(variables) {
        allVariables = variables;
        var selFrom = document.getElementById('pathFrom');
        var selTo = document.getElementById('pathTo');
        selFrom.innerHTML = '';
        selTo.innerHTML = '';
        variables.forEach(function (v) {
            var label = v.replace(/_/g, ' ');
            selFrom.innerHTML += '<option value="' + v + '">' + label + '</option>';
            selTo.innerHTML += '<option value="' + v + '">' + label + '</option>';
        });
        if (variables.length > 1) selTo.selectedIndex = 1;
    }

    // ── find paths ──
    function findPaths() {
        var from = document.getElementById('pathFrom').value;
        var to = document.getElementById('pathTo').value;
        var div = document.getElementById('pathResults');
        if (!from || !to) { div.innerHTML = '<p class="text-muted">Select source and target.</p>'; return; }
        if (from === to) { div.innerHTML = '<p class="text-warning">Source and target must differ.</p>'; return; }
        div.innerHTML = '<div class="text-center"><div class="spinner-border spinner-border-sm"></div></div>';

        apiPost(causalPathsUrl, { from: from, to: to, limit: 20 }).then(function (d) {
            if (!d.success) { div.innerHTML = '<p class="text-danger">' + d.error + '</p>'; return; }
            if (d.path_count === 0) {
                div.innerHTML = '<p class="text-muted">No directed paths found (max depth 6).</p>';
                return;
            }
            var html = '<p class="mb-2"><strong>' + d.path_count + '</strong> path(s) found</p>';
            html += '<div class="path-list">';
            d.paths.forEach(function (path, i) {
                html += '<div class="path-item"><span class="path-num">#' + (i + 1) + '</span> ';
                html += path.map(function (n) { return '<span class="path-node">' + n.replace(/_/g, ' ') + '</span>'; }).join(' → ');
                html += '</div>';
            });
            html += '</div>';
            div.innerHTML = html;
        }).catch(function () {
            div.innerHTML = '<p class="text-danger">Request failed.</p>';
        });
    }

    // ── init ──
    document.addEventListener('DOMContentLoaded', function () {
        show('analysisLoading');
        hide('noGraphPlaceholder');
        hide('analysisResults');

        apiGet(summaryUrl).then(function (d) {
            hide('analysisLoading');
            if (!d.success) {
                show('noGraphPlaceholder');
                return;
            }
            renderSummary(d);
            show('analysisResults');
            // also load variables for dropdowns
            return apiGet(variablesUrl);
        }).then(function (d) {
            if (d && d.success) populateDropdowns(d.variables);
        }).catch(function () {
            hide('analysisLoading');
            show('noGraphPlaceholder');
        });

        document.getElementById('btnFindPaths').addEventListener('click', findPaths);
    });
})();

