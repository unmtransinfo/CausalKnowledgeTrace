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
    function populateDropdowns(variables, exposures, outcomes) {
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
        // Pre-select exposure as source and outcome as target
        if (exposures && exposures.length > 0) selFrom.value = exposures[0];
        if (outcomes && outcomes.length > 0) selTo.value = outcomes[0];
    }

    // ── find paths ──
    function findPaths() {
        var from = document.getElementById('pathFrom').value;
        var to = document.getElementById('pathTo').value;
        var div = document.getElementById('pathResults');
        if (!from || !to) { div.innerHTML = '<p class="text-muted">Select source and target.</p>'; return; }
        if (from === to) { div.innerHTML = '<p class="text-warning">Source and target must differ.</p>'; return; }
        div.innerHTML = '<div class="text-center"><div class="spinner-border spinner-border-sm"></div></div>';

        apiPost(causalPathsUrl, { from: from, to: to, limit: 50 }).then(function (d) {
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

    // ── Stage 3: cycle analysis ──
    function runCycleAnalysis() {
        var div = document.getElementById('cycleResults');
        div.innerHTML = '<div class="text-center"><div class="spinner-border spinner-border-sm"></div> Enumerating cycles…</div>';

        apiGet(cycleAnalysisUrl).then(function (d) {
            if (!d.success) { div.innerHTML = '<p class="text-danger">' + d.error + '</p>'; return; }
            var html = '<div class="row g-3 mb-3">';
            html += '<div class="col-md-3"><div class="stat-box"><strong>' + d.total_cycles + '</strong><br>Total Cycles</div></div>';
            html += '<div class="col-md-3"><div class="stat-box"><strong>' + d.nodes_in_cycles + '</strong><br>Nodes in Cycles</div></div>';
            html += '<div class="col-md-3"><div class="stat-box"><strong>' + Object.keys(d.length_distribution || {}).length + '</strong><br>Distinct Lengths</div></div>';
            html += '</div>';

            if (d.node_participation && d.node_participation.length > 0) {
                html += '<h6>Top Cycle-Participating Nodes</h6>';
                html += '<table class="table table-sm table-striped"><thead><tr><th>Node</th><th class="text-end">Cycle Count</th><th class="text-end">% of Total</th></tr></thead><tbody>';
                var totalCycles = d.total_cycles || 1;
                d.node_participation.forEach(function (n) {
                    var pct = ((n.count / totalCycles) * 100).toFixed(1);
                    html += '<tr><td>' + n.node.replace(/_/g, ' ') + '</td><td class="text-end">' + n.count + '</td><td class="text-end">' + pct + '%</td></tr>';
                });
                html += '</tbody></table>';
            }

            if (d.sampled_cycles && d.sampled_cycles.length > 0) {
                html += '<h6>Sample Cycles</h6><div class="path-list">';
                d.sampled_cycles.slice(0, 10).forEach(function (c) {
                    var cycleNodes = c.nodes.slice();
                    if (cycleNodes.length > 0) {
                        cycleNodes.push(cycleNodes[0]);
                    }
                    html += '<div class="path-item"><span class="path-num">Len ' + c.length + '</span> ';
                    html += cycleNodes.map(function (n) { return '<span class="path-node">' + n.replace(/_/g, ' ') + '</span>'; }).join(' → ');
                    html += '</div>';
                });
                html += '</div>';
            }
            div.innerHTML = html;
        }).catch(function () { div.innerHTML = '<p class="text-danger">Request failed.</p>'; });
    }

    // ── Stage 4: node removal ──
    function runNodeRemoval() {
        var div = document.getElementById('nodeRemovalResults');
        var customInput = document.getElementById('customNodesToRemove').value.trim();
        var body = {};
        if (customInput) {
            body.nodes_to_remove = customInput.split(',').map(function (s) { return s.trim(); }).filter(Boolean);
        }
        div.innerHTML = '<div class="text-center"><div class="spinner-border spinner-border-sm"></div> Analyzing removal impact…</div>';

        apiPost(nodeRemovalUrl, body).then(function (d) {
            if (!d.success) { div.innerHTML = '<p class="text-danger">' + d.error + '</p>'; return; }
            var html = '<div class="row g-3 mb-3">';
            html += '<div class="col-md-3"><div class="stat-box"><strong>' + d.baseline_cycles.toLocaleString() + '</strong><br>Baseline Cycles</div></div>';
            html += '<div class="col-md-3"><div class="stat-box"><strong>' + d.combined_cycles.toLocaleString() + '</strong><br>Cycles After Removal</div></div>';
            html += '<div class="col-md-3"><div class="stat-box"><strong>' + d.reduced_nodes + ' / ' + d.reduced_edges + '</strong><br>Reduced Graph (Nodes / Edges)</div></div>';
            html += '<div class="col-md-3"><div class="stat-box ' + (d.is_dag_after ? 'stat-success' : 'stat-warning') + '"><strong>' + (d.is_dag_after ? 'YES' : 'NO') + '</strong><br>Is DAG?</div></div>';
            html += '</div>';

            html += '<p><strong>Nodes removed:</strong> ' + (d.nodes_removed || []).map(function (n) { return '<span class="badge bg-secondary me-1">' + n.replace(/_/g, ' ') + '</span>'; }).join('') + '</p>';

            if (d.individual_impact && d.individual_impact.length > 0) {
                html += '<h6>Individual Node Impact</h6>';
                html += '<table class="table table-sm table-striped"><thead><tr><th>Node</th><th class="text-end">Cycles Removed</th><th class="text-end">% Reduction</th></tr></thead><tbody>';
                d.individual_impact.forEach(function (n) {
                    html += '<tr><td>' + n.node.replace(/_/g, ' ') + '</td><td class="text-end">' + n.cycles_removed + '</td><td class="text-end">' + n.percent_reduction + '%</td></tr>';
                });
                html += '</tbody></table>';
            }

            // Show saved reduced graph path for CLI usage
            if (d.reduced_graph_path) {
                html += '<div class="alert alert-info py-2 mt-3"><i class="fas fa-save"></i> <strong>Reduced graph saved:</strong> <code>' + d.reduced_graph_path + '</code>';
                html += '<br><small class="text-muted">Use with CLI: <code>python run_bias_analysis.py ' + d.reduced_graph_path + ' &lt;exposure&gt; &lt;outcome&gt;</code></small></div>';
            }

            div.innerHTML = html;
        }).catch(function () { div.innerHTML = '<p class="text-danger">Request failed.</p>'; });
    }

    // ── Stage 5: post-removal ──
    function runPostRemoval() {
        var div = document.getElementById('postRemovalResults');
        div.innerHTML = '<div class="text-center"><div class="spinner-border spinner-border-sm"></div> Comparing graphs…</div>';

        apiGet(postRemovalUrl).then(function (d) {
            if (!d.success) { div.innerHTML = '<p class="text-danger">' + d.error + '</p>'; return; }
            var html = '<div class="row g-3 mb-3">';
            html += '<div class="col-md-2"><div class="stat-box"><strong>' + d.original_cycles + '</strong><br>Original Cycles</div></div>';
            html += '<div class="col-md-2"><div class="stat-box"><strong>' + d.reduced_cycles + '</strong><br>Reduced Cycles</div></div>';
            html += '<div class="col-md-2"><div class="stat-box"><strong>' + d.cycle_reduction_pct + '%</strong><br>Reduction</div></div>';
            html += '<div class="col-md-2"><div class="stat-box"><strong>' + d.reduced_nodes + '</strong><br>Nodes Left</div></div>';
            html += '<div class="col-md-2"><div class="stat-box"><strong>' + d.reduced_edges + '</strong><br>Edges Left</div></div>';
            html += '<div class="col-md-2"><div class="stat-box ' + (d.is_dag ? 'stat-success' : 'stat-warning') + '"><strong>' + (d.is_dag ? 'DAG ✓' : 'Cyclic') + '</strong><br>Status</div></div>';
            html += '</div>';

            if (d.next_removal_candidates && d.next_removal_candidates.length > 0) {
                html += '<h6>Suggested Next Removals</h6>';
                html += '<table class="table table-sm table-striped"><thead><tr><th>Node</th><th class="text-end">Cycle Participation</th></tr></thead><tbody>';
                d.next_removal_candidates.forEach(function (n) {
                    html += '<tr><td>' + n.node.replace(/_/g, ' ') + '</td><td class="text-end">' + n.count + '</td></tr>';
                });
                html += '</tbody></table>';
            }
            div.innerHTML = html;
        }).catch(function () { div.innerHTML = '<p class="text-danger">Request failed.</p>'; });
    }

    // ── causal inference ──
    var _ciPanelId = 0;

    function renderBadgeList(items, badgeClass, limit) {
        if (!items || items.length === 0) return '';
        var id = 'ciBadges' + (++_ciPanelId);
        var html = '<div class="mb-3">';
        var visible = items.slice(0, limit);
        var hidden = items.slice(limit);
        html += visible.map(function (n) { return '<span class="badge ' + badgeClass + ' me-1 mb-1">' + n.replace(/_/g, ' ') + '</span>'; }).join('');
        if (hidden.length > 0) {
            html += '<span id="' + id + '" style="display:none;">';
            html += hidden.map(function (n) { return '<span class="badge ' + badgeClass + ' me-1 mb-1">' + n.replace(/_/g, ' ') + '</span>'; }).join('');
            html += '</span>';
            html += ' <a href="#" class="badge bg-light text-primary border" onclick="var el=document.getElementById(\'' + id + '\');el.style.display=\'\';this.style.display=\'none\';return false;">+ ' + hidden.length + ' more</a>';
        }
        html += '</div>';
        return html;
    }

    function renderInferencePanel(r) {
        var html = '';
        if (r.warnings && r.warnings.length > 0) {
            html += '<div class="alert alert-warning py-2 mb-2">';
            r.warnings.forEach(function (w) { html += '<div><i class="fas fa-exclamation-triangle"></i> ' + w + '</div>'; });
            html += '</div>';
        }
        html += '<div class="row g-3 mb-3">';
        html += '<div class="col-md-4"><div class="stat-box ' + (r.is_dag ? 'stat-success' : 'stat-warning') + '"><strong>' + (r.is_dag ? 'DAG ✓' : 'Cyclic ✗') + '</strong><br>Graph Status</div></div>';
        html += '<div class="col-md-4"><div class="stat-box"><strong>' + (r.adjustment_sets || []).length + '</strong><br>Adjustment Variables</div></div>';
        html += '<div class="col-md-4"><div class="stat-box"><strong>' + (r.instrumental_variables || []).length + '</strong><br>Instrumental Variables</div></div>';
        html += '</div>';
        html += '<h6><i class="fas fa-shield-alt"></i> Adjustment Set (Backdoor Criterion)</h6>';
        if (r.adjustment_sets && r.adjustment_sets.length > 0) {
            html += renderBadgeList(r.adjustment_sets, 'bg-primary', 10);
        } else {
            html += '<p class="text-muted mb-3">No adjustment variables found.</p>';
        }
        html += '<h6><i class="fas fa-key"></i> Instrumental Variables</h6>';
        if (r.instrumental_variables && r.instrumental_variables.length > 0) {
            html += renderBadgeList(r.instrumental_variables, 'bg-success', 10);
        } else {
            html += '<p class="text-muted mb-3">No instrumental variables found.</p>';
        }
        return html;
    }

    function renderComparisonPanel(orig, red) {
        var html = '';
        var oAdj = orig.adjustment_sets || [];
        var rAdj = red.adjustment_sets || [];
        var oIV = orig.instrumental_variables || [];
        var rIV = red.instrumental_variables || [];

        html += '<div class="row g-3 mb-3">';
        html += '<div class="col-md-4"><div class="stat-box"><strong>' + (orig.is_dag ? 'DAG ✓' : 'Cyclic ✗') + ' → ' + (red.is_dag ? 'DAG ✓' : 'Cyclic ✗') + '</strong><br>Graph Status</div></div>';
        html += '<div class="col-md-4"><div class="stat-box"><strong>' + oAdj.length + ' → ' + rAdj.length + '</strong><br>Adjustment Variables</div></div>';
        html += '<div class="col-md-4"><div class="stat-box"><strong>' + oIV.length + ' → ' + rIV.length + '</strong><br>Instrumental Variables</div></div>';
        html += '</div>';

        // Adjustment set comparison
        var oAdjSet = new Set(oAdj);
        var rAdjSet = new Set(rAdj);
        var addedAdj = rAdj.filter(function (n) { return !oAdjSet.has(n); });
        var removedAdj = oAdj.filter(function (n) { return !rAdjSet.has(n); });
        var keptAdj = oAdj.filter(function (n) { return rAdjSet.has(n); });

        html += '<h6><i class="fas fa-shield-alt"></i> Adjustment Set Changes</h6>';
        if (keptAdj.length > 0) {
            html += '<div class="mb-1"><small class="text-muted">Unchanged:</small> ' + renderBadgeList(keptAdj, 'bg-secondary', 10) + '</div>';
        }
        if (addedAdj.length > 0) {
            html += '<div class="mb-1"><small class="text-muted">Added in reduced:</small> ' + renderBadgeList(addedAdj.map(function (n) { return '+ ' + n; }), 'bg-success', 10) + '</div>';
        }
        if (removedAdj.length > 0) {
            html += '<div class="mb-1"><small class="text-muted">Removed (node gone):</small> ' + renderBadgeList(removedAdj.map(function (n) { return '− ' + n; }), 'bg-danger', 10) + '</div>';
        }
        if (keptAdj.length === 0 && addedAdj.length === 0 && removedAdj.length === 0) {
            html += '<p class="text-muted mb-2">No adjustment variables in either graph.</p>';
        }

        // IV comparison
        var oIVSet = new Set(oIV);
        var rIVSet = new Set(rIV);
        var addedIV = rIV.filter(function (n) { return !oIVSet.has(n); });
        var removedIV = oIV.filter(function (n) { return !rIVSet.has(n); });
        var keptIV = oIV.filter(function (n) { return rIVSet.has(n); });

        html += '<h6 class="mt-3"><i class="fas fa-key"></i> Instrumental Variable Changes</h6>';
        if (keptIV.length > 0) {
            html += '<div class="mb-1"><small class="text-muted">Unchanged:</small> ' + renderBadgeList(keptIV, 'bg-secondary', 10) + '</div>';
        }
        if (addedIV.length > 0) {
            html += '<div class="mb-1"><small class="text-muted">Added in reduced:</small> ' + renderBadgeList(addedIV.map(function (n) { return '+ ' + n; }), 'bg-success', 10) + '</div>';
        }
        if (removedIV.length > 0) {
            html += '<div class="mb-1"><small class="text-muted">Removed (node gone):</small> ' + renderBadgeList(removedIV.map(function (n) { return '− ' + n; }), 'bg-danger', 10) + '</div>';
        }
        if (keptIV.length === 0 && addedIV.length === 0 && removedIV.length === 0) {
            html += '<p class="text-muted mb-2">No instrumental variables in either graph.</p>';
        }

        return html;
    }

    function runCausalInference() {
        var exposure = document.getElementById('ciExposure').value;
        var outcome = document.getElementById('ciOutcome').value;
        var div = document.getElementById('causalInferenceResults');
        if (!exposure || !outcome) { div.innerHTML = '<p class="text-muted">Select exposure and outcome.</p>'; return; }
        if (exposure === outcome) { div.innerHTML = '<p class="text-warning">Exposure and outcome must differ.</p>'; return; }
        div.innerHTML = '<div class="text-center"><div class="spinner-border spinner-border-sm"></div> Running inference…</div>';

        apiPost(causalInferenceUrl, { exposure: exposure, outcome: outcome }).then(function (d) {
            if (!d.success) { div.innerHTML = '<p class="text-danger">' + d.error + '</p>'; return; }
            var orig = d.original;
            var red = d.reduced;
            var hasBoth = d.has_reduced && red;

            // Build tabs
            var html = '<ul class="nav nav-tabs mb-3" role="tablist">';
            html += '<li class="nav-item"><a class="nav-link active" data-bs-toggle="tab" href="#ciOriginal" role="tab">Original Graph</a></li>';
            if (hasBoth) {
                html += '<li class="nav-item"><a class="nav-link" data-bs-toggle="tab" href="#ciReduced" role="tab">Reduced Graph</a></li>';
                html += '<li class="nav-item"><a class="nav-link" data-bs-toggle="tab" href="#ciComparison" role="tab">Comparison</a></li>';
            }
            html += '</ul>';

            html += '<div class="tab-content">';
            html += '<div class="tab-pane fade show active" id="ciOriginal" role="tabpanel">' + renderInferencePanel(orig) + '</div>';
            if (hasBoth) {
                html += '<div class="tab-pane fade" id="ciReduced" role="tabpanel">' + renderInferencePanel(red) + '</div>';
                html += '<div class="tab-pane fade" id="ciComparison" role="tabpanel">' + renderComparisonPanel(orig, red) + '</div>';
            }
            html += '</div>';

            if (!hasBoth) {
                html += '<p class="text-muted mt-2"><small><i class="fas fa-info-circle"></i> Run Node Removal first to also see results on the reduced graph.</small></p>';
            }

            div.innerHTML = html;
        }).catch(function () { div.innerHTML = '<p class="text-danger">Request failed.</p>'; });
    }

    // ── populate causal inference dropdowns ──
    function populateCIDropdowns(variables, exposures, outcomes) {
        var selExp = document.getElementById('ciExposure');
        var selOut = document.getElementById('ciOutcome');
        selExp.innerHTML = '';
        selOut.innerHTML = '';
        variables.forEach(function (v) {
            var label = v.replace(/_/g, ' ');
            selExp.innerHTML += '<option value="' + v + '">' + label + '</option>';
            selOut.innerHTML += '<option value="' + v + '">' + label + '</option>';
        });
        if (exposures && exposures.length > 0) selExp.value = exposures[0];
        if (outcomes && outcomes.length > 0) selOut.value = outcomes[0];
    }

    // ── populate bias analysis dropdowns ──
    function populateBiasDropdowns(variables, exposures, outcomes) {
        var selExp = document.getElementById('biasExposure');
        var selOut = document.getElementById('biasOutcome');
        selExp.innerHTML = '';
        selOut.innerHTML = '';
        variables.forEach(function (v) {
            var label = v.replace(/_/g, ' ');
            selExp.innerHTML += '<option value="' + v + '">' + label + '</option>';
            selOut.innerHTML += '<option value="' + v + '">' + label + '</option>';
        });
        if (exposures && exposures.length > 0) selExp.value = exposures[0];
        if (outcomes && outcomes.length > 0) selOut.value = outcomes[0];
    }

    // ── bias analysis ──
    function runBiasAnalysis() {
        var exposure = document.getElementById('biasExposure').value;
        var outcome = document.getElementById('biasOutcome').value;
        var div = document.getElementById('biasResults');
        if (!exposure || !outcome) { div.innerHTML = '<p class="text-muted">Select exposure and outcome.</p>'; return; }
        if (exposure === outcome) { div.innerHTML = '<p class="text-warning">Exposure and outcome must differ.</p>'; return; }
        div.innerHTML = '<div class="text-center"><div class="spinner-border spinner-border-sm"></div> Running bias analysis…</div>';

        apiPost(biasAnalysisUrl, { exposure: exposure, outcome: outcome }).then(function (d) {
            if (!d.success) { div.innerHTML = '<p class="text-danger">' + (d.error || d.warnings.join(', ')) + '</p>'; return; }
            var html = '';

            // Warnings
            if (d.warnings && d.warnings.length > 0) {
                html += '<div class="alert alert-warning py-2 mb-2">';
                d.warnings.forEach(function (w) { html += '<div><i class="fas fa-exclamation-triangle"></i> ' + w + '</div>'; });
                html += '</div>';
            }

            // Graph info
            html += '<div class="row g-3 mb-3">';
            html += '<div class="col-md-3"><div class="stat-box ' + (d.is_dag ? 'stat-success' : 'stat-warning') + '"><strong>' + (d.is_dag ? 'DAG ✓' : 'Cyclic ✗') + '</strong><br>Graph Status</div></div>';
            html += '<div class="col-md-3"><div class="stat-box stat-success"><strong>Reduced Graph</strong><br>Analysis On</div></div>';
            html += '<div class="col-md-3"><div class="stat-box"><strong>' + d.node_count + ' / ' + d.edge_count + '</strong><br>Nodes / Edges</div></div>';
            html += '</div>';

            // Variable Roles
            var roles = d.roles || {};
            html += '<h6 class="mt-3"><i class="fas fa-tags"></i> Variable Roles</h6>';
            html += renderRoleSection('Confounders', roles.confounders, 'bg-warning text-dark');
            html += renderRoleSection('Mediators', roles.mediators, 'bg-info');
            html += renderRoleSection('Colliders', roles.colliders, 'bg-secondary');
            html += renderRoleSection('Instrumental Variables', roles.instrumental_variables, 'bg-success');
            html += renderRoleSection('Precision Variables', roles.precision_variables, 'bg-primary');
            html += renderRoleSection('Adjustment Set', roles.adjustment_set, 'bg-dark');

            // Butterfly Bias
            var bfly = d.butterfly || {};
            html += '<h6 class="mt-4"><i class="fas fa-bug"></i> Butterfly Bias</h6>';
            if (bfly.butterfly_vars && bfly.butterfly_vars.length > 0) {
                html += '<div class="alert alert-danger py-2 mb-2"><i class="fas fa-exclamation-circle"></i> <strong>' + bfly.butterfly_vars.length + ' butterfly bias variable(s) detected</strong></div>';
                bfly.butterfly_vars.forEach(function (v) {
                    var pars = (bfly.butterfly_parents && bfly.butterfly_parents[v]) || [];
                    html += '<div class="mb-2"><span class="badge bg-danger me-1">' + v.replace(/_/g, ' ') + '</span>';
                    html += '<small class="text-muted">parents: </small>';
                    pars.forEach(function (p) { html += '<span class="badge bg-warning text-dark me-1">' + p.replace(/_/g, ' ') + '</span>'; });
                    html += '</div>';
                });
                if (bfly.valid_sets && bfly.valid_sets.length > 0) {
                    html += '<div class="mt-2"><strong>Valid adjustment sets (avoiding butterfly bias):</strong></div>';
                    bfly.valid_sets.forEach(function (s, i) {
                        html += '<div class="mb-1"><small class="text-muted">Set ' + (i + 1) + ':</small> ';
                        s.forEach(function (n) { html += '<span class="badge bg-primary me-1 mb-1">' + n.replace(/_/g, ' ') + '</span>'; });
                        html += '</div>';
                    });
                }
            } else {
                html += '<p class="text-success mb-2"><i class="fas fa-check-circle"></i> No butterfly bias detected.</p>';
            }

            // M-Bias
            var mb = d.mbias || {};
            html += '<h6 class="mt-4"><i class="fas fa-project-diagram"></i> M-Bias</h6>';
            if (mb.mbias_vars && mb.mbias_vars.length > 0) {
                var cappedNote = mb.capped ? ' (showing top ' + mb.mbias_vars.length + ')' : '';
                html += '<div class="alert alert-danger py-2 mb-2"><i class="fas fa-exclamation-circle"></i> <strong>' + mb.mbias_vars.length + ' M-bias variable(s) detected' + cappedNote + '</strong> — do NOT condition on these</div>';
                mb.mbias_vars.forEach(function (v) {
                    var det = (mb.mbias_details && mb.mbias_details[v]) || {};
                    html += '<div class="mb-2"><span class="badge bg-danger me-1">' + v.replace(/_/g, ' ') + '</span>';
                    html += '<small class="text-muted">parents: </small>';
                    (det.parents || []).forEach(function (p) { html += '<span class="badge bg-secondary me-1">' + p.replace(/_/g, ' ') + '</span>'; });
                    if (det.sample_path && det.sample_path.length > 0) {
                        html += '<small class="text-muted ms-2">path: ' + det.sample_path.join(' → ') + '</small>';
                    }
                    html += '</div>';
                });
            } else {
                html += '<p class="text-success mb-2"><i class="fas fa-check-circle"></i> No M-bias detected.</p>';
            }

            div.innerHTML = html;
        }).catch(function () { div.innerHTML = '<p class="text-danger">Request failed.</p>'; });
    }

    function renderRoleSection(label, items, badgeClass) {
        var html = '<div class="mb-2"><small class="text-muted">' + label + ' (' + (items ? items.length : 0) + '):</small> ';
        if (items && items.length > 0) {
            html += renderBadgeList(items, badgeClass, 8);
        } else {
            html += '<span class="text-muted">None</span>';
        }
        html += '</div>';
        return html;
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

            // Auto-fire cycle analysis in background (non-blocking)
            runCycleAnalysis();

            return apiGet(variablesUrl);
        }).then(function (d) {
            if (d && d.success) {
                populateDropdowns(d.variables, d.exposures, d.outcomes);
                populateCIDropdowns(d.variables, d.exposures, d.outcomes);
                populateBiasDropdowns(d.variables, d.exposures, d.outcomes);
            }
        }).catch(function () {
            hide('analysisLoading');
            show('noGraphPlaceholder');
        });

        document.getElementById('btnFindPaths').addEventListener('click', findPaths);
        document.getElementById('btnRunCycles').addEventListener('click', runCycleAnalysis);
        document.getElementById('btnRunNodeRemoval').addEventListener('click', runNodeRemoval);
        document.getElementById('btnRunPostRemoval').addEventListener('click', runPostRemoval);
        document.getElementById('btnRunCausalInference').addEventListener('click', runCausalInference);
        document.getElementById('btnRunBiasAnalysis').addEventListener('click', runBiasAnalysis);
    });
})();

