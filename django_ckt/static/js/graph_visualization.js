
/**
 * CKT Graph Visualization — vis-network Integration
 * Uses the same vis.js library as the Shiny/R visNetwork app,
 * with identical forceAtlas2Based / barnesHut physics parameters.
 */
(function() {
    'use strict';

    var network = null;
    var nodesDataSet = null;
    var edgesDataSet = null;
    var selectedElement = null;
    var rawGraphElements = null;

    // ── Color palette: Red=exposure, Green=outcome, Gray=everything else ──
    var COLORS = {
        exposure: '#E53935',
        outcome:  '#43A047',
        other:    '#9E9E9E',
        edge:     '#aaaaaa',
        edgeHl:   '#00bcd4',
        selected: '#FFD700',
    };

    // ── Physics strength (maps to gravitationalConstant, user-adjustable) ──
    var physicsStrength = -150;

    // ── Build physics options matching Shiny/visNetwork (dag_visualization.R) ──
    // R thresholds: is_large_graph = node_count > 5000 || edge_count > 15000
    // Small: forceAtlas2Based, gravitationalConstant=-150, centralGravity=0.01,
    //        springLength=200, springConstant=0.08, damping=0.4, avoidOverlap=1
    // Large: barnesHut, gravitationalConstant=physicsStrength*1.5, centralGravity=0.2,
    //        springLength=140, springConstant=0.08, damping=0.9, avoidOverlap=0.2
    function getPhysicsOptions(nodeCount, edgeCount) {
        edgeCount = edgeCount || 0;
        var isLarge = nodeCount > 5000 || edgeCount > 15000;
        if (isLarge) {
            return {
                enabled: true,
                solver: 'barnesHut',
                barnesHut: {
                    gravitationalConstant: physicsStrength * 1.5,
                    centralGravity: 0.2,
                    springLength: 140,
                    springConstant: 0.08,
                    damping: 0.9,
                    avoidOverlap: 0.2,
                },
                stabilization: { enabled: true, iterations: 1000 },
            };
        }
        return {
            enabled: true,
            solver: 'forceAtlas2Based',
            forceAtlas2Based: {
                gravitationalConstant: physicsStrength,
                centralGravity: 0.01,
                springLength: 200,
                springConstant: 0.08,
                damping: 0.4,
                avoidOverlap: 1,
            },
            stabilization: { enabled: true, iterations: 1000 },
        };
    }

    // ── Map node role → vis-network visual properties ──
    function nodeStyle(role) {
        var base = {
            size: 40,
            font: { size: 18, face: 'Arial', strokeWidth: 2, strokeColor: '#ffffff' },
            shadow: true,
            borderWidth: 2,
        };
        if (role === 'exposure') {
            base.color = { background: COLORS.exposure, border: '#B71C1C', highlight: { background: '#EF5350', border: '#B71C1C' } };
            base.borderWidth = 3;
            base.font.bold = true;
        } else if (role === 'outcome') {
            base.color = { background: COLORS.outcome, border: '#1B5E20', highlight: { background: '#66BB6A', border: '#1B5E20' } };
            base.borderWidth = 3;
            base.font.bold = true;
        } else {
            base.color = { background: COLORS.other, border: '#757575', highlight: { background: '#BDBDBD', border: '#616161' } };
        }
        return base;
    }

    // ── Compute node metrics and convert to vis-network DataSets ──
    function computeNodeMetrics(elements) {
        var rawNodes = elements.nodes || [];
        var rawEdges = elements.edges || [];

        // 1. Degree per node
        var degMap = {};
        rawNodes.forEach(function(n) { degMap[n.data.id] = 0; });
        rawEdges.forEach(function(e) {
            var s = e.data.source, t = e.data.target;
            if (degMap[s] !== undefined) degMap[s]++;
            if (degMap[t] !== undefined) degMap[t]++;
        });

        // 2. Find exposure/outcome IDs
        var exposureIds = new Set();
        var outcomeIds  = new Set();
        rawNodes.forEach(function(n) {
            var nt = n.data.node_type || n.data.type || '';
            if (nt === 'exposure') exposureIds.add(n.data.id);
            if (nt === 'outcome')  outcomeIds.add(n.data.id);
        });

        // 3. Build neighbor sets
        var expNeighbors = new Set();
        var outNeighbors = new Set();
        rawEdges.forEach(function(e) {
            var s = e.data.source, t = e.data.target;
            if (exposureIds.has(s)) expNeighbors.add(t);
            if (exposureIds.has(t)) expNeighbors.add(s);
            if (outcomeIds.has(s))  outNeighbors.add(t);
            if (outcomeIds.has(t))  outNeighbors.add(s);
        });

        // 4. Log-scale size_score (0–100)
        var maxDeg = Math.max.apply(null, Object.values(degMap).concat([1]));
        var logMax = Math.log(maxDeg + 1);

        // 5. Build vis nodes
        var visNodes = [];
        rawNodes.forEach(function(n) {
            var id = n.data.id;
            var deg = degMap[id] || 0;
            var sizeScore = Math.round((Math.log(deg + 1) / logMax) * 100);

            var nt = n.data.node_type || n.data.type || '';
            var role;
            if (nt === 'exposure')                                    role = 'exposure';
            else if (nt === 'outcome')                                role = 'outcome';
            else if (expNeighbors.has(id) && outNeighbors.has(id))    role = 'both_neighbor';
            else if (expNeighbors.has(id))                            role = 'exp_neighbor';
            else if (outNeighbors.has(id))                            role = 'out_neighbor';
            else                                                      role = 'other';

            var style = nodeStyle(role);
            visNodes.push(Object.assign({
                id: id,
                label: n.data.label || id,
                title: (n.data.label || id) + ' (degree: ' + deg + ')',
                shape: 'dot',
                role: role,
                degree: deg,
                sizeScore: sizeScore,
                _rawData: n.data,
            }, style));
        });

        // 6. Edge score — log-scaled evidence_count
        var maxEvid = 1;
        rawEdges.forEach(function(e) {
            var ec = e.data.evidence_count || 1;
            if (ec > maxEvid) maxEvid = ec;
        });
        var logMaxEvid = Math.log(maxEvid + 1);

        var visEdges = [];
        rawEdges.forEach(function(e) {
            var ec = e.data.evidence_count || 1;
            var edgeScore = Math.round((Math.log(ec + 1) / logMaxEvid) * 100);
            var w = 0.8 + (edgeScore / 100) * 2.2;  // 0.8–3 px
            visEdges.push({
                id: e.data.id,
                from: e.data.source,
                to: e.data.target,
                arrows: 'to',
                width: w,
                color: { color: '#37474F', opacity: 0.55, highlight: '#ff9800' },
                _rawData: e.data,
            });
        });

        return { visNodes: visNodes, visEdges: visEdges, nodeCount: rawNodes.length, edgeCount: rawEdges.length };
    }

    // ── Initialize vis-network instance ──
    function initNetwork(rawElements) {
        if (network) { network.destroy(); network = null; }

        rawGraphElements = rawElements;

        document.getElementById('noGraphPlaceholder').style.display = 'none';
        document.getElementById('cy').style.display = 'block';

        // Compute metrics and build vis DataSets
        var metrics = computeNodeMetrics(rawElements);
        nodesDataSet = new vis.DataSet(metrics.visNodes);
        edgesDataSet = new vis.DataSet(metrics.visEdges);
        var nodeCount = metrics.nodeCount;
        var edgeCount = metrics.edgeCount;
        var isLarge = nodeCount > 5000 || edgeCount > 15000;

        var container = document.getElementById('cy');
        var data = { nodes: nodesDataSet, edges: edgesDataSet };

        // Edge smooth options: R uses curvedCW for small, disabled for large
        var edgeSmooth = isLarge
            ? { enabled: false }
            : { enabled: true, type: 'curvedCW' };

        var options = {
            physics: getPhysicsOptions(nodeCount, edgeCount),
            interaction: {
                dragNodes: true,
                dragView: true,
                zoomView: true,
                hover: !isLarge ? true : true,
                hoverConnectedEdges: !isLarge,  // R: FALSE for large
                tooltipDelay: isLarge ? 200 : 300,  // R: 200 (large) / 300 (small)
                keyboard: { enabled: true, speed: { x: 10, y: 10, zoom: 0.02 } },
                navigationButtons: true,
                selectConnectedEdges: true,
                zoomSpeed: 0.3,
            },
            edges: {
                smooth: edgeSmooth,
                arrows: { to: { enabled: true, scaleFactor: isLarge ? 0.9 : 1 } },
                width: isLarge ? 1.5 : undefined,
                color: isLarge ? { color: '#666666', opacity: 0.7 } : undefined,
            },
            nodes: {
                shape: 'dot',
            },
            layout: {
                randomSeed: 123,  // R: visLayout(randomSeed = 123)
            },
        };

        network = new vis.Network(container, data, options);

        // ── Event bindings ──
        network.on('click', function(params) {
            if (params.nodes.length > 0) {
                onNodeClick(params.nodes[0]);
            } else if (params.edges.length > 0) {
                onEdgeClick(params.edges[0]);
            } else {
                clearSelection();
            }
        });

        updateStats(rawElements);
    }

    // ── Node click handler ──
    function onNodeClick(nodeId) {
        clearHighlights();
        var nodeData = nodesDataSet.get(nodeId);
        if (!nodeData) return;
        selectedElement = { type: 'node', id: nodeId, data: nodeData };
        document.getElementById('btnRemoveSelected').disabled = false;

        // Highlight: fade all, then restore selected + neighbors
        var connEdgeIds = network.getConnectedEdges(nodeId);
        var connNodeIds = network.getConnectedNodes(nodeId);

        // Fade non-connected nodes
        var updates = [];
        nodesDataSet.forEach(function(n) {
            if (n.id !== nodeId && connNodeIds.indexOf(n.id) === -1) {
                updates.push({ id: n.id, opacity: 0.12, _wasFaded: true });
            }
        });
        nodesDataSet.update(updates);

        // Fade non-connected edges
        var edgeUpdates = [];
        edgesDataSet.forEach(function(e) {
            if (connEdgeIds.indexOf(e.id) === -1) {
                edgeUpdates.push({ id: e.id, color: { opacity: 0.04 }, _wasFaded: true });
            }
        });
        edgesDataSet.update(edgeUpdates);

        showNodeInfo(nodeId);
    }

    // ── Edge click handler ──
    function onEdgeClick(edgeId) {
        clearHighlights();
        var edgeData = edgesDataSet.get(edgeId);
        if (!edgeData) return;
        selectedElement = { type: 'edge', id: edgeId, data: edgeData };
        document.getElementById('btnRemoveSelected').disabled = false;

        // Fade everything except this edge and its endpoints
        var srcId = edgeData.from;
        var tgtId = edgeData.to;
        var updates = [];
        nodesDataSet.forEach(function(n) {
            if (n.id !== srcId && n.id !== tgtId) {
                updates.push({ id: n.id, opacity: 0.12, _wasFaded: true });
            }
        });
        nodesDataSet.update(updates);

        var edgeUpdates = [];
        edgesDataSet.forEach(function(e) {
            if (e.id !== edgeId) {
                edgeUpdates.push({ id: e.id, color: { opacity: 0.04 }, _wasFaded: true });
            }
        });
        edgesDataSet.update(edgeUpdates);

        var srcData = nodesDataSet.get(srcId);
        var tgtData = nodesDataSet.get(tgtId);
        showEdgeInfo(edgeData, srcData, tgtData);
    }

    // ── Clear selection ──
    function clearSelection() {
        selectedElement = null;
        document.getElementById('btnRemoveSelected').disabled = true;
        clearHighlights();
        document.getElementById('infoPanelBody').innerHTML =
            '<p class="text-muted">Click on a node or edge to see details.</p>';
    }

    function clearHighlights() {
        if (!nodesDataSet || !edgesDataSet) return;
        // Restore opacity on all nodes/edges that were faded
        var nodeUpdates = [];
        nodesDataSet.forEach(function(n) {
            if (n._wasFaded) nodeUpdates.push({ id: n.id, opacity: 1, _wasFaded: false });
        });
        if (nodeUpdates.length) nodesDataSet.update(nodeUpdates);

        var edgeUpdates = [];
        edgesDataSet.forEach(function(e) {
            if (e._wasFaded) edgeUpdates.push({ id: e.id, color: { color: '#37474F', opacity: 0.55 }, _wasFaded: false });
        });
        if (edgeUpdates.length) edgesDataSet.update(edgeUpdates);
    }

    // ── Info panel renderers ──
    function showNodeInfo(nodeId) {
        var data = nodesDataSet.get(nodeId);
        if (!data) return;
        var connEdgeIds = network.getConnectedEdges(nodeId);

        // Count incoming/outgoing
        var incoming = 0, outgoing = 0;
        connEdgeIds.forEach(function(eid) {
            var e = edgesDataSet.get(eid);
            if (e) {
                if (e.to === nodeId) incoming++;
                if (e.from === nodeId) outgoing++;
            }
        });

        var role = data.role || 'other';
        var nodeColor = role === 'exposure' ? COLORS.exposure
            : role === 'outcome' ? COLORS.outcome : COLORS.other;
        var typeLabel = role === 'exposure' ? 'Exposure'
            : role === 'outcome' ? 'Outcome' : 'Other';

        // Build evidence rows from all connected edges
        var edgeInfoArray = [];
        connEdgeIds.forEach(function(eid) {
            var e = edgesDataSet.get(eid);
            if (!e) return;
            var rawData = e._rawData || e;
            var srcNode = nodesDataSet.get(e.from);
            var tgtNode = nodesDataSet.get(e.to);
            edgeInfoArray.push({
                rawData: rawData,
                fromLabel: srcNode ? (srcNode.label || srcNode.id) : e.from,
                toLabel: tgtNode ? (tgtNode.label || tgtNode.id) : e.to,
            });
        });

        currentEvidenceRows = buildEvidenceRows(edgeInfoArray);
        currentEvidencePage = 1;
        currentEvidenceFilter = '';

        // Build header with node summary + evidence table
        var headerHtml = '<div class="node-info-summary">';
        headerHtml += '<h6 style="margin:0 0 8px"><i class="fas fa-circle" style="color:' + nodeColor + '"></i> ' + escapeHtml(data.label || data.id) + '</h6>';
        headerHtml += infoRow('Type', typeLabel);
        headerHtml += infoRow('Connections', connEdgeIds.length + ' (' + incoming + ' in, ' + outgoing + ' out)');
        headerHtml += '</div>';

        var title = 'Node Information: ' + (data.label || data.id);
        var html = headerHtml + renderEvidenceTable(title);
        document.getElementById('infoPanelBody').innerHTML = html;
        bindEvidenceEvents(title);
    }

    // ── Evidence table helpers ──
    var EVIDENCE_PAGE_SIZE = 10;
    var currentEvidenceRows = [];
    var currentEvidencePage = 1;
    var currentEvidenceFilter = '';

    function buildEvidenceRows(edgeDataArray) {
        // edgeDataArray: array of { fromLabel, predicate, toLabel, pmid, sentence }
        var rows = [];
        edgeDataArray.forEach(function(edgeInfo) {
            var rawData = edgeInfo.rawData || {};
            var pmidData = rawData.pmid_data || {};
            var fromLabel = edgeInfo.fromLabel;
            var toLabel = edgeInfo.toLabel;
            var predicate = rawData.predicate || rawData.relationship || rawData.label || '—';
            var fromCui = rawData.subject_cui ? ' [' + rawData.subject_cui + ']' : '';
            var toCui = rawData.object_cui ? ' [' + rawData.object_cui + ']' : '';

            var pmids = Object.keys(pmidData);
            if (pmids.length === 0) {
                // No PMID data, add a single row
                rows.push({
                    fromNode: fromLabel + fromCui,
                    predicate: predicate,
                    toNode: toLabel + toCui,
                    pmid: '—',
                    sentence: '—',
                });
            } else {
                pmids.forEach(function(pmid) {
                    var sentences = pmidData[pmid] || [];
                    if (sentences.length === 0) {
                        rows.push({
                            fromNode: fromLabel + fromCui,
                            predicate: predicate,
                            toNode: toLabel + toCui,
                            pmid: pmid,
                            sentence: '—',
                        });
                    } else {
                        // Combine all sentences for this PMID into one row
                        var combinedSentence = sentences.join(' ');
                        if (combinedSentence.length > 300) {
                            combinedSentence = combinedSentence.substring(0, 300) + '...';
                        }
                        rows.push({
                            fromNode: fromLabel + fromCui,
                            predicate: predicate,
                            toNode: toLabel + toCui,
                            pmid: pmid,
                            sentence: combinedSentence,
                        });
                    }
                });
            }
        });
        return rows;
    }

    function getFilteredRows() {
        if (!currentEvidenceFilter) return currentEvidenceRows;
        var q = currentEvidenceFilter.toLowerCase();
        return currentEvidenceRows.filter(function(r) {
            return r.fromNode.toLowerCase().indexOf(q) !== -1 ||
                   r.predicate.toLowerCase().indexOf(q) !== -1 ||
                   r.toNode.toLowerCase().indexOf(q) !== -1 ||
                   r.pmid.toLowerCase().indexOf(q) !== -1 ||
                   r.sentence.toLowerCase().indexOf(q) !== -1;
        });
    }

    function renderEvidenceTable(title) {
        var filtered = getFilteredRows();
        var totalRows = filtered.length;
        var totalPages = Math.max(1, Math.ceil(totalRows / EVIDENCE_PAGE_SIZE));
        if (currentEvidencePage > totalPages) currentEvidencePage = totalPages;
        var startIdx = (currentEvidencePage - 1) * EVIDENCE_PAGE_SIZE;
        var endIdx = Math.min(startIdx + EVIDENCE_PAGE_SIZE, totalRows);
        var pageRows = filtered.slice(startIdx, endIdx);

        var html = '<div class="evidence-header">';
        html += '<h6 class="evidence-title"><i class="fas fa-arrow-right"></i> ' + title + '</h6>';
        html += '<div class="evidence-search"><label>Search: <input type="text" id="evidenceSearchInput" value="' + escapeHtml(currentEvidenceFilter) + '"></label></div>';
        html += '</div>';

        html += '<div class="evidence-table-wrap"><table class="evidence-table">';
        html += '<thead><tr>';
        html += '<th>From Node</th><th>Predicate</th><th>To Node</th><th>PMID</th><th>Causal Sentences</th>';
        html += '</tr></thead><tbody>';

        if (pageRows.length === 0) {
            html += '<tr><td colspan="5" style="text-align:center;color:#999;">No matching records found.</td></tr>';
        } else {
            pageRows.forEach(function(r) {
                var pmidCell = r.pmid !== '—'
                    ? '<a href="https://pubmed.ncbi.nlm.nih.gov/' + r.pmid + '/" target="_blank" rel="noopener">' + r.pmid + '</a>'
                    : '—';
                html += '<tr>';
                html += '<td>' + escapeHtml(r.fromNode) + '</td>';
                html += '<td>' + escapeHtml(r.predicate) + '</td>';
                html += '<td>' + escapeHtml(r.toNode) + '</td>';
                html += '<td>' + pmidCell + '</td>';
                html += '<td class="sentence-cell">' + escapeHtml(r.sentence) + '</td>';
                html += '</tr>';
            });
        }
        html += '</tbody></table></div>';

        // Pagination
        html += '<div class="evidence-pagination">';
        html += '<span class="evidence-page-info">Showing ' + (totalRows > 0 ? startIdx + 1 : 0) + ' to ' + endIdx + ' of ' + totalRows + ' entries</span>';
        html += '<span class="evidence-page-buttons">';
        html += '<button class="btn btn-sm btn-outline-secondary" id="evidencePrev"' + (currentEvidencePage <= 1 ? ' disabled' : '') + '>Previous</button>';
        for (var p = 1; p <= totalPages && p <= 7; p++) {
            html += '<button class="btn btn-sm ' + (p === currentEvidencePage ? 'btn-primary' : 'btn-outline-secondary') + ' evidence-page-btn" data-page="' + p + '">' + p + '</button>';
        }
        if (totalPages > 7) {
            html += '<span>...</span>';
            html += '<button class="btn btn-sm btn-outline-secondary evidence-page-btn" data-page="' + totalPages + '">' + totalPages + '</button>';
        }
        html += '<button class="btn btn-sm btn-outline-secondary" id="evidenceNext"' + (currentEvidencePage >= totalPages ? ' disabled' : '') + '>Next</button>';
        html += '</span></div>';

        return html;
    }

    function escapeHtml(str) {
        if (!str) return '';
        return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
    }

    function bindEvidenceEvents(title) {
        var searchInput = document.getElementById('evidenceSearchInput');
        if (searchInput) {
            searchInput.addEventListener('input', function() {
                currentEvidenceFilter = this.value;
                currentEvidencePage = 1;
                document.getElementById('infoPanelBody').innerHTML = renderEvidenceTable(title);
                bindEvidenceEvents(title);
            });
            // Focus the search input and restore cursor position
            searchInput.focus();
            searchInput.setSelectionRange(searchInput.value.length, searchInput.value.length);
        }
        var prevBtn = document.getElementById('evidencePrev');
        if (prevBtn) {
            prevBtn.addEventListener('click', function() {
                if (currentEvidencePage > 1) {
                    currentEvidencePage--;
                    document.getElementById('infoPanelBody').innerHTML = renderEvidenceTable(title);
                    bindEvidenceEvents(title);
                }
            });
        }
        var nextBtn = document.getElementById('evidenceNext');
        if (nextBtn) {
            nextBtn.addEventListener('click', function() {
                var filtered = getFilteredRows();
                var totalPages = Math.max(1, Math.ceil(filtered.length / EVIDENCE_PAGE_SIZE));
                if (currentEvidencePage < totalPages) {
                    currentEvidencePage++;
                    document.getElementById('infoPanelBody').innerHTML = renderEvidenceTable(title);
                    bindEvidenceEvents(title);
                }
            });
        }
        document.querySelectorAll('.evidence-page-btn').forEach(function(btn) {
            btn.addEventListener('click', function() {
                currentEvidencePage = parseInt(this.getAttribute('data-page'), 10);
                document.getElementById('infoPanelBody').innerHTML = renderEvidenceTable(title);
                bindEvidenceEvents(title);
            });
        });
    }

    function showEdgeInfo(data, srcData, tgtData) {
        var rawData = data._rawData || data;
        var fromLabel = srcData ? (srcData.label || srcData.id) : data.from;
        var toLabel = tgtData ? (tgtData.label || tgtData.id) : data.to;

        currentEvidenceRows = buildEvidenceRows([{
            rawData: rawData,
            fromLabel: fromLabel,
            toLabel: toLabel,
        }]);
        currentEvidencePage = 1;
        currentEvidenceFilter = '';

        var title = 'Edge Information: ' + fromLabel + ' → ' + toLabel;
        document.getElementById('infoPanelBody').innerHTML = renderEvidenceTable(title);
        bindEvidenceEvents(title);
    }

    function infoRow(label, value) {
        return '<div class="info-row"><span class="info-label">' + label + '</span><span class="info-value">' + value + '</span></div>';
    }

    // ── Stats ──
    function updateStats(elements) {
        var nodeCount = (elements.nodes || []).length;
        var edgeCount = (elements.edges || []).length;
        document.getElementById('statNodes').textContent = nodeCount;
        document.getElementById('statEdges').textContent = edgeCount;
    }

    // ── API helpers ──
    function apiPost(url, body) {
        return fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'X-CSRFToken': csrfToken },
            body: JSON.stringify(body),
        }).then(function(r) { return r.json(); });
    }

    // ── Remove selected element ──
    function removeSelected() {
        if (!selectedElement) return;

        var isNode = selectedElement.type === 'node';
        var data = selectedElement.data;
        var rawData = data._rawData || data;

        var url = isNode ? removeNodeUrl : removeEdgeUrl;
        var body = isNode
            ? { node_id: data.id }
            : { edge_id: data.id, from: rawData.source || data.from, to: rawData.target || data.to };

        apiPost(url, body).then(function(resp) {
            if (resp.success) {
                var elems = { nodes: resp.nodes, edges: resp.edges };
                initNetwork(elems);
                document.getElementById('btnUndo').disabled = false;
                clearSelection();
            } else {
                alert('Error: ' + (resp.error || 'Unknown error'));
            }
        }).catch(function(err) {
            alert('Network error: ' + err.message);
        });
    }

    // ── Undo ──
    function undoLast() {
        apiPost(undoUrl, {}).then(function(resp) {
            if (resp.success) {
                var elems = { nodes: resp.nodes, edges: resp.edges };
                initNetwork(elems);
                clearSelection();
            } else {
                alert(resp.error || 'Nothing to undo');
                document.getElementById('btnUndo').disabled = true;
            }
        }).catch(function(err) {
            alert('Network error: ' + err.message);
        });
    }

    // ── Layout switching ──
    function runLayout(name) {
        if (!network) return;
        if (name === 'physics') {
            var nodeCount = nodesDataSet.length;
            var edgeCount = edgesDataSet.length;
            network.setOptions({ physics: getPhysicsOptions(nodeCount, edgeCount) });
        } else {
            // Disable physics for non-physics layouts
            network.setOptions({ physics: { enabled: false } });
        }
    }

    // ── Toggle physics controls visibility ──
    function updatePhysicsControlsVisibility() {
        var sel = document.getElementById('layoutSelect');
        var controls = document.getElementById('physicsControls');
        if (sel && controls) {
            controls.style.display = (sel.value === 'physics') ? 'flex' : 'none';
        }
    }

    // ── Load graph from server ──
    function loadGraphFromServer() {
        fetch(networkDataUrl)
            .then(function(r) { return r.json(); })
            .then(function(data) {
                if (data.success && data.nodes && data.nodes.length > 0) {
                    var elems = { nodes: data.nodes, edges: data.edges };
                    rawGraphElements = elems;
                    initNetwork(elems);
                    document.getElementById('statFilename').textContent = data.filename || 'Loaded';
                } else {
                    document.getElementById('noGraphPlaceholder').style.display = 'flex';
                    document.getElementById('cy').style.display = 'none';
                }
            })
            .catch(function(err) {
                console.error('Failed to load graph:', err);
                document.getElementById('noGraphPlaceholder').style.display = 'flex';
                document.getElementById('cy').style.display = 'none';
            });
    }

    // ── Responsive resizable panels (side-by-side ↔ stacked) ──
    var HANDLE_SIZE = 6;
    var INFO_MIN_W = 200;   // below this width → switch to stacked
    var GRAPH_MIN_W = 250;
    var GRAPH_MIN_H = 150;
    var INFO_MIN_H = 80;
    var WRAPPER_MIN_H = 300;
    var WRAPPER_MAX_OFFSET = 150; // leave this much room above wrapper

    function isModeSide() {
        return document.getElementById('resizableWrapper').classList.contains('mode-side');
    }

    function updateToggleLabel() {
        var label = document.getElementById('toggleLayoutLabel');
        if (label) label.textContent = isModeSide() ? 'Stack' : 'Side-by-Side';
    }

    function switchToStacked() {
        var wrapper = document.getElementById('resizableWrapper');
        var graphPane = document.getElementById('graphPane');
        var infoPane = document.getElementById('infoPane');
        wrapper.classList.remove('mode-side');
        wrapper.classList.add('mode-stacked');
        // Reset flex to stacked defaults
        graphPane.style.flex = '';
        infoPane.style.flex = '';
        if (network) network.redraw();
        updateToggleLabel();
    }

    function switchToSide() {
        var wrapper = document.getElementById('resizableWrapper');
        var graphPane = document.getElementById('graphPane');
        var infoPane = document.getElementById('infoPane');
        wrapper.classList.remove('mode-stacked');
        wrapper.classList.add('mode-side');
        // Reset flex to side-by-side defaults
        graphPane.style.flex = '';
        infoPane.style.flex = '';
        if (network) network.redraw();
        updateToggleLabel();
    }

    function initResizableHandles() {
        var wrapper = document.getElementById('resizableWrapper');
        var graphPane = document.getElementById('graphPane');
        var infoPane = document.getElementById('infoPane');
        var handleV = document.getElementById('resizeHandleV');
        var handleH = document.getElementById('resizeHandleH');
        var handleBottom = document.getElementById('resizeHandleBottom');

        var draggingV = false;
        var draggingH = false;
        var draggingBottom = false;

        // ── Vertical handle (side-by-side mode) ──
        handleV.addEventListener('mousedown', function(e) {
            if (!isModeSide()) return;
            e.preventDefault();
            draggingV = true;
            handleV.classList.add('active');
            document.body.classList.add('resizing-v');
        });

        // ── Horizontal handle (stacked mode) ──
        handleH.addEventListener('mousedown', function(e) {
            if (isModeSide()) return;
            e.preventDefault();
            draggingH = true;
            handleH.classList.add('active');
            document.body.classList.add('resizing-h');
        });

        // ── Bottom handle (overall wrapper height, both modes) ──
        handleBottom.addEventListener('mousedown', function(e) {
            e.preventDefault();
            draggingBottom = true;
            handleBottom.classList.add('active');
            document.body.classList.add('resizing-h');
        });

        document.addEventListener('mousemove', function(e) {
            if (draggingV) {
                var rect = wrapper.getBoundingClientRect();
                var offsetX = e.clientX - rect.left;
                var totalW = rect.width;
                var graphW = Math.max(GRAPH_MIN_W, Math.min(offsetX, totalW - INFO_MIN_W - HANDLE_SIZE));
                var infoW = totalW - graphW - HANDLE_SIZE;

                // Auto-switch to stacked if graph pane occupies >= 80% of wrapper width
                if (graphW / totalW >= 0.8) {
                    draggingV = false;
                    handleV.classList.remove('active');
                    document.body.classList.remove('resizing-v');
                    switchToStacked();
                    return;
                }

                graphPane.style.flex = '0 0 ' + graphW + 'px';
                infoPane.style.flex = '0 0 ' + infoW + 'px';
                if (network) network.redraw();
            }
            if (draggingH) {
                var rect = wrapper.getBoundingClientRect();
                var offsetY = e.clientY - rect.top;
                var totalH = rect.height;
                var graphH = Math.max(GRAPH_MIN_H, Math.min(offsetY, totalH - INFO_MIN_H - HANDLE_SIZE));
                var infoH = totalH - graphH - HANDLE_SIZE;

                // Auto-switch back to side-by-side if graph pane shrinks below 50% of wrapper height
                // and viewport is wide enough
                if (graphH / totalH < 0.5 && window.innerWidth >= 768) {
                    var wrapperW = rect.width;
                    if (wrapperW >= GRAPH_MIN_W + INFO_MIN_W + HANDLE_SIZE) {
                        draggingH = false;
                        handleH.classList.remove('active');
                        document.body.classList.remove('resizing-h');
                        switchToSide();
                        return;
                    }
                }

                graphPane.style.flex = '0 0 ' + graphH + 'px';
                infoPane.style.flex = '0 0 ' + infoH + 'px';
                if (network) network.redraw();
            }
            if (draggingBottom) {
                var rect = wrapper.getBoundingClientRect();
                var maxH = window.innerHeight - WRAPPER_MAX_OFFSET;
                var newH = Math.max(WRAPPER_MIN_H, Math.min(e.clientY - rect.top, maxH));

                // In stacked mode, distribute proportionally between panes
                if (!isModeSide()) {
                    var oldH = rect.height;
                    var graphRect = graphPane.getBoundingClientRect();
                    var infoRect = infoPane.getBoundingClientRect();
                    var ratio = oldH > HANDLE_SIZE ? graphRect.height / (oldH - HANDLE_SIZE) : 0.7;
                    var graphH = Math.max(GRAPH_MIN_H, Math.round((newH - HANDLE_SIZE) * ratio));
                    var infoH = Math.max(INFO_MIN_H, newH - HANDLE_SIZE - graphH);
                    // Re-clamp graph if info was clamped
                    graphH = newH - HANDLE_SIZE - infoH;

                    // Auto-switch back to side-by-side if graph pane < 50% of new height
                    if (graphH / newH < 0.5 && window.innerWidth >= 768) {
                        var wrapperW = rect.width;
                        if (wrapperW >= GRAPH_MIN_W + INFO_MIN_W + HANDLE_SIZE) {
                            draggingBottom = false;
                            handleBottom.classList.remove('active');
                            document.body.classList.remove('resizing-h');
                            wrapper.style.height = newH + 'px';
                            switchToSide();
                            return;
                        }
                    }

                    graphPane.style.flex = '0 0 ' + graphH + 'px';
                    infoPane.style.flex = '0 0 ' + infoH + 'px';
                }

                wrapper.style.height = newH + 'px';
                if (network) network.redraw();
            }
        });

        document.addEventListener('mouseup', function() {
            if (draggingV) {
                draggingV = false;
                handleV.classList.remove('active');
                document.body.classList.remove('resizing-v');
                if (network) network.redraw();
            }
            if (draggingH) {
                draggingH = false;
                handleH.classList.remove('active');
                document.body.classList.remove('resizing-h');
                if (network) { network.redraw(); network.fit(); }
            }
            if (draggingBottom) {
                draggingBottom = false;
                handleBottom.classList.remove('active');
                document.body.classList.remove('resizing-h');
                if (network) { network.redraw(); network.fit(); }
            }
        });

        // ── Window resize: force stacked on small screens, revert on wide ──
        window.addEventListener('resize', function() {
            if (window.innerWidth < 768) {
                // Small screen → always stacked
                if (isModeSide()) switchToStacked();
            } else if (!isModeSide()) {
                var wrapperW = wrapper.getBoundingClientRect().width;
                if (wrapperW >= GRAPH_MIN_W + INFO_MIN_W + HANDLE_SIZE) {
                    switchToSide();
                }
            }
        });

        // ── Initial check: if page loads on a small screen, start stacked ──
        if (window.innerWidth < 768 && isModeSide()) {
            switchToStacked();
        }
    }

    // ── Button bindings ──
    document.addEventListener('DOMContentLoaded', function() {
        document.getElementById('btnFit').addEventListener('click', function() {
            if (network) network.fit();
        });
        document.getElementById('btnZoomIn').addEventListener('click', function() {
            if (network) {
                var scale = network.getScale() * 1.3;
                network.moveTo({ scale: scale });
            }
        });
        document.getElementById('btnZoomOut').addEventListener('click', function() {
            if (network) {
                var scale = network.getScale() / 1.3;
                network.moveTo({ scale: scale });
            }
        });
        document.getElementById('btnRemoveSelected').addEventListener('click', removeSelected);
        document.getElementById('btnUndo').addEventListener('click', undoLast);
        document.getElementById('btnRelayout').addEventListener('click', function() {
            runLayout(document.getElementById('layoutSelect').value);
        });

        // Show/hide physics slider when layout selection changes
        document.getElementById('layoutSelect').addEventListener('change', function() {
            updatePhysicsControlsVisibility();
        });

        // Physics strength slider — maps to gravitationalConstant (-500 to 0)
        var physicsSlider = document.getElementById('physicsStrength');
        var physicsVal = document.getElementById('physicsStrengthVal');
        if (physicsSlider) {
            physicsSlider.addEventListener('input', function() {
                physicsStrength = parseInt(this.value, 10);
                if (physicsVal) physicsVal.textContent = physicsStrength;
            });
            physicsSlider.addEventListener('change', function() {
                if (document.getElementById('layoutSelect').value === 'physics') {
                    runLayout('physics');
                }
            });
        }

        // Set initial visibility of physics controls
        updatePhysicsControlsVisibility();
        document.getElementById('btnToggleLayout').addEventListener('click', function() {
            if (isModeSide()) {
                switchToStacked();
            } else {
                switchToSide();
            }
            if (network) network.fit();
        });

        // Initialize resizable drag handles
        initResizableHandles();

        // Load graph data on page load
        loadGraphFromServer();
    });

})();
