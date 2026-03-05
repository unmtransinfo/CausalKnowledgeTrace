/**
 * CKT Graph Visualization - Cytoscape.js Integration
 */
(function() {
    'use strict';

    let cy = null;
    let selectedElement = null;

    // ── Color palette ──
    var COLORS = {
        exposure:     '#FF6B6B',  // Coral red
        outcome:      '#4ECDC4',  // Soft teal
        expNeighbor:  '#F5A6A6',  // Light coral — nodes connected to exposure
        outNeighbor:  '#A8DCD5',  // Light teal  — nodes connected to outcome
        bothNeighbor: '#C9A0DC',  // Lavender    — connected to both
        other:        '#B0BEC5',  // Blue-gray   — not directly connected
        edge:         '#aaaaaa',
        edgeHl:       '#00bcd4',
        selected:     '#FFD700',
    };

    // ── Cytoscape style ──
    // Uses 'size_score' (log-scaled 0–100) computed by computeNodeMetrics()
    // Uses 'role' data field: exposure, outcome, exp_neighbor, out_neighbor,
    //                          both_neighbor, other
    const cyStyle = [
        // ── Base node style (fallback for 'other' role) ──
        {
            selector: 'node',
            style: {
                'label': 'data(label)',
                'background-color': COLORS.other,
                'color': '#444',
                'text-valign': 'bottom',
                'text-halign': 'center',
                'font-size': '9px',
                'font-family': 'Arial, Helvetica, sans-serif',
                'text-margin-y': 4,
                'width': 35,
                'height': 35,
                'border-width': 1,
                'border-color': '#90A4AE',
                'text-max-width': '90px',
                'text-wrap': 'ellipsis',
                'min-zoomed-font-size': 10,
                'background-opacity': 'mapData(size_score, 0, 100, 0.55, 1)',
            }
        },
        // ── Role-based colors for default nodes ──
        {
            selector: 'node[role="exp_neighbor"]',
            style: {
                'background-color': COLORS.expNeighbor,
                'border-color': '#E57373',
                'color': '#8B0000',
            }
        },
        {
            selector: 'node[role="out_neighbor"]',
            style: {
                'background-color': COLORS.outNeighbor,
                'border-color': '#4DB6AC',
                'color': '#004D40',
            }
        },
        {
            selector: 'node[role="both_neighbor"]',
            style: {
                'background-color': COLORS.bothNeighbor,
                'border-color': '#AB47BC',
                'color': '#4A148C',
            }
        },
        // ── Exposure / Outcome nodes — always prominent ──
        {
            selector: 'node[role="exposure"]',
            style: {
                'background-color': COLORS.exposure,
                'border-color': '#C62828',
                'border-width': 3,
                'width': 35,
                'height': 35,
                'font-size': '13px',
                'font-weight': 'bold',
                'color': '#B71C1C',
                'background-opacity': 1,
                'text-max-width': '150px',
            }
        },
        {
            selector: 'node[role="outcome"]',
            style: {
                'background-color': COLORS.outcome,
                'border-color': '#00897B',
                'border-width': 3,
                'width': 35,
                'height': 35,
                'font-size': '13px',
                'font-weight': 'bold',
                'color': '#00695C',
                'background-opacity': 1,
                'text-max-width': '150px',
            }
        },
        // ── Selection / highlight states ──
        {
            selector: 'node:selected',
            style: {
                'border-width': 3,
                'border-color': COLORS.selected,
                'overlay-color': COLORS.selected,
                'overlay-opacity': 0.15,
            }
        },
        {
            selector: 'node.highlighted',
            style: {
                'border-width': 2,
                'border-color': COLORS.edgeHl,
                'overlay-color': COLORS.edgeHl,
                'overlay-opacity': 0.1,
            }
        },
        // ── Edges ──
        {
            selector: 'edge',
            style: {
                'width': 'mapData(edge_score, 0, 100, 0.4, 3)',
                'line-color': '#CFD8DC',
                'target-arrow-color': '#CFD8DC',
                'target-arrow-shape': 'triangle',
                'curve-style': 'bezier',
                'arrow-scale': 0.6,
                'opacity': 0.35,
            }
        },
        {
            selector: 'edge:selected',
            style: {
                'width': 3,
                'line-color': '#ff9800',
                'target-arrow-color': '#ff9800',
                'opacity': 1,
                'overlay-color': '#ff9800',
                'overlay-opacity': 0.15,
            }
        },
        {
            selector: 'edge.highlighted',
            style: {
                'width': 2.5,
                'line-color': COLORS.edgeHl,
                'target-arrow-color': COLORS.edgeHl,
                'opacity': 0.9,
            }
        },
        // ── Faded states ──
        {
            selector: 'node.faded',
            style: { 'opacity': 0.12 }
        },
        {
            selector: 'edge.faded',
            style: { 'opacity': 0.04 }
        },
    ];

    // ── Raw element store (server data) ──
    var rawGraphElements = null;

    // ── Check fCoSE availability ──
    var fcoseAvailable = (typeof cytoscape !== 'undefined') &&
        cytoscape.extensions && typeof cytoscape.extensions === 'function'
        ? false  // we'll detect via trial below
        : false;
    // Simpler: just check if the layout name resolves at runtime
    try {
        // cytoscape-fcose registers itself automatically when loaded via script tag
        // after cytoscape.js. If cose-base/layout-base were missing it won't register.
        var _testCy = cytoscape({ headless: true, elements: [] });
        _testCy.layout({ name: 'fcose' });
        _testCy.destroy();
        fcoseAvailable = true;
    } catch (e) {
        console.warn('fCoSE layout extension not available, falling back to cose:', e.message);
        fcoseAvailable = false;
    }

    // ── Physics layout parameters ──
    // Base repulsion — auto-scaled by node count in getPhysicsLayoutOpts
    var physicsRepulsion = 8000;

    // Auto-scale physics based on graph size (like R/visNetwork forceAtlas2Based)
    function getPhysicsLayoutOpts(nodeCount) {
        nodeCount = nodeCount || 50;
        // Scale repulsion: more nodes → more spread needed
        var scaledRepulsion = physicsRepulsion * Math.max(1, nodeCount / 80);
        // Scale edge length with node count
        var edgeLen = Math.min(300, Math.max(100, nodeCount * 0.6));
        // Weaker gravity for larger graphs so they spread
        var grav = Math.max(0.02, 0.25 - (nodeCount * 0.0006));

        if (!fcoseAvailable) {
            return {
                name: 'cose',
                animate: true,
                animationDuration: 1600,
                nodeRepulsion: function() { return scaledRepulsion; },
                idealEdgeLength: function() { return edgeLen; },
                edgeElasticity: function() { return 0.45; },
                gravity: grav,
                numIter: 3500,
                padding: 60,
                randomize: true,
            };
        }
        return {
            name: 'fcose',
            quality: 'proof',
            animate: true,
            animationDuration: 1600,
            animationEasing: 'ease-out',
            randomize: true,

            nodeRepulsion: scaledRepulsion,
            idealEdgeLength: edgeLen,
            edgeElasticity: 0.45,

            gravity: grav,
            gravityRange: 5.0,

            numIter: 3500,
            initialEnergyOnIncremental: 0.5,

            tile: true,
            tilingPaddingVertical: 25,
            tilingPaddingHorizontal: 25,

            packComponents: true,
            padding: 60,
        };
    }

    // ── Compute node metrics: degree, role, size_score ──
    // Injects data fields used by cyStyle's mapData() and role selectors.
    function computeNodeMetrics(elements) {
        var nodes = elements.nodes || [];
        var edges = elements.edges || [];

        // 1. Degree per node
        var degMap = {};
        nodes.forEach(function(n) { degMap[n.data.id] = 0; });
        edges.forEach(function(e) {
            var s = e.data.source, t = e.data.target;
            if (degMap[s] !== undefined) degMap[s]++;
            if (degMap[t] !== undefined) degMap[t]++;
        });

        // 2. Find exposure/outcome IDs
        var exposureIds = new Set();
        var outcomeIds  = new Set();
        nodes.forEach(function(n) {
            var nt = n.data.node_type || n.data.type || '';
            if (nt === 'exposure') exposureIds.add(n.data.id);
            if (nt === 'outcome')  outcomeIds.add(n.data.id);
        });

        // 3. Build neighbor sets: which nodes connect to exposure / outcome
        var expNeighbors = new Set();
        var outNeighbors = new Set();
        edges.forEach(function(e) {
            var s = e.data.source, t = e.data.target;
            if (exposureIds.has(s)) expNeighbors.add(t);
            if (exposureIds.has(t)) expNeighbors.add(s);
            if (outcomeIds.has(s))  outNeighbors.add(t);
            if (outcomeIds.has(t))  outNeighbors.add(s);
        });

        // 4. Log-scale size_score (0–100) — handles extreme skew (e.g. 329 vs 1)
        var maxDeg = Math.max.apply(null, Object.values(degMap).concat([1]));
        var logMax = Math.log(maxDeg + 1);

        nodes.forEach(function(n) {
            var id = n.data.id;
            var deg = degMap[id] || 0;
            n.data.degree = deg;
            n.data.size_score = Math.round((Math.log(deg + 1) / logMax) * 100);

            // Assign role for color styling
            var nt = n.data.node_type || n.data.type || '';
            if (nt === 'exposure') {
                n.data.role = 'exposure';
            } else if (nt === 'outcome') {
                n.data.role = 'outcome';
            } else if (expNeighbors.has(id) && outNeighbors.has(id)) {
                n.data.role = 'both_neighbor';
            } else if (expNeighbors.has(id)) {
                n.data.role = 'exp_neighbor';
            } else if (outNeighbors.has(id)) {
                n.data.role = 'out_neighbor';
            } else {
                n.data.role = 'other';
            }
        });

        // 5. Edge score — log-scaled evidence_count (fallback to 1)
        var maxEvid = 1;
        edges.forEach(function(e) {
            var ec = e.data.evidence_count || 1;
            if (ec > maxEvid) maxEvid = ec;
        });
        var logMaxEvid = Math.log(maxEvid + 1);
        edges.forEach(function(e) {
            var ec = e.data.evidence_count || 1;
            e.data.edge_score = Math.round((Math.log(ec + 1) / logMaxEvid) * 100);
        });

        return elements;
    }

    // ── Initialize Cytoscape instance ──
    function initCytoscape(rawElements) {
        if (cy) { cy.destroy(); }

        // Store raw server elements
        rawGraphElements = rawElements;

        document.getElementById('noGraphPlaceholder').style.display = 'none';
        document.getElementById('cy').style.display = 'block';

        var layoutName = document.getElementById('layoutSelect')
            ? document.getElementById('layoutSelect').value
            : 'physics';

        // Compute degree, role, size_score for styling (mapData + role selectors)
        var elements = computeNodeMetrics(rawElements);
        var nodeCount = (elements.nodes || []).length;

        var initLayout = (layoutName === 'physics')
            ? getPhysicsLayoutOpts(nodeCount)
            : { name: layoutName, animate: true, animationDuration: 800, padding: 30 };

        cy = cytoscape({
            container: document.getElementById('cy'),
            elements: elements,
            style: cyStyle,
            layout: initLayout,
            minZoom: 0.05,
            maxZoom: 6,
            wheelSensitivity: 0.3,
        });

        // Event bindings
        cy.on('tap', 'node', onNodeTap);
        cy.on('tap', 'edge', onEdgeTap);
        cy.on('tap', function(evt) {
            if (evt.target === cy) { clearSelection(); }
        });

        updateStats(rawElements);
    }

    // ── Node tap handler ──
    function onNodeTap(evt) {
        clearHighlights();
        selectedElement = evt.target;
        document.getElementById('btnRemoveSelected').disabled = false;

        // Highlight connected
        const neighborhood = selectedElement.neighborhood();
        cy.elements().addClass('faded');
        selectedElement.removeClass('faded');
        neighborhood.removeClass('faded');
        neighborhood.nodes().addClass('highlighted');
        neighborhood.edges().addClass('highlighted');

        showNodeInfo(selectedElement.data());
    }

    // ── Edge tap handler ──
    function onEdgeTap(evt) {
        clearHighlights();
        selectedElement = evt.target;
        document.getElementById('btnRemoveSelected').disabled = false;

        const src = cy.getElementById(selectedElement.data('source'));
        const tgt = cy.getElementById(selectedElement.data('target'));
        cy.elements().addClass('faded');
        selectedElement.removeClass('faded');
        src.removeClass('faded').addClass('highlighted');
        tgt.removeClass('faded').addClass('highlighted');

        showEdgeInfo(selectedElement.data(), src.data(), tgt.data());
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
        if (!cy) return;
        cy.elements().removeClass('faded highlighted');
    }

    // ── Info panel renderers ──
    function showNodeInfo(data) {
        const connEdges = cy.getElementById(data.id).connectedEdges();
        const incoming = connEdges.filter(e => e.data('target') === data.id);
        const outgoing = connEdges.filter(e => e.data('source') === data.id);

        var role = data.role || 'other';
        var nodeColor = role === 'exposure' ? COLORS.exposure
            : role === 'outcome' ? COLORS.outcome
            : role === 'exp_neighbor' ? COLORS.expNeighbor
            : role === 'out_neighbor' ? COLORS.outNeighbor
            : role === 'both_neighbor' ? COLORS.bothNeighbor
            : COLORS.other;
        var typeLabel = role === 'exposure' ? 'Exposure'
            : role === 'outcome' ? 'Outcome'
            : role === 'exp_neighbor' ? 'Exposure Neighbor'
            : role === 'out_neighbor' ? 'Outcome Neighbor'
            : role === 'both_neighbor' ? 'Shared Neighbor'
            : 'Other';
        let html = '<h6 style="margin:0 0 8px;color:var(--text-success)"><i class="fas fa-circle" style="color:' + nodeColor + '"></i> ' + (data.label || data.id) + '</h6>';
        html += infoRow('ID', data.id);
        html += infoRow('Type', typeLabel);
        html += infoRow('Connections', connEdges.length + ' (' + incoming.length + ' in, ' + outgoing.length + ' out)');

        // List connected nodes
        if (connEdges.length > 0) {
            html += '<hr style="margin:8px 0">';
            html += '<strong style="font-size:0.83rem">Connected Nodes:</strong>';
            html += '<ul class="connected-list">';
            const neighbors = cy.getElementById(data.id).neighborhood().nodes();
            neighbors.forEach(function(n) {
                var nRole = n.data('role') || 'other';
                var nColor = nRole === 'exposure' ? COLORS.exposure
                    : nRole === 'outcome' ? COLORS.outcome
                    : nRole === 'exp_neighbor' ? COLORS.expNeighbor
                    : nRole === 'out_neighbor' ? COLORS.outNeighbor
                    : nRole === 'both_neighbor' ? COLORS.bothNeighbor
                    : COLORS.other;
                html += '<li data-id="' + n.data('id') + '"><i class="fas fa-circle" style="color:' + nColor + ';font-size:8px"></i> ' + (n.data('label') || n.data('id')) + '</li>';
            });
            html += '</ul>';
        }

        document.getElementById('infoPanelBody').innerHTML = html;

        // Click to focus on connected node
        document.querySelectorAll('.connected-list li').forEach(function(li) {
            li.addEventListener('click', function() {
                const nid = this.getAttribute('data-id');
                const node = cy.getElementById(nid);
                if (node.length) {
                    cy.animate({ center: { eles: node }, zoom: cy.zoom() }, { duration: 300 });
                    node.emit('tap');
                }
            });
        });
    }

    function showEdgeInfo(data, srcData, tgtData) {
        let html = '<h6 style="margin:0 0 8px;color:var(--text-warning)"><i class="fas fa-arrow-right"></i> Edge</h6>';
        html += infoRow('ID', data.id);
        html += infoRow('Relationship', data.relationship || data.label || '—');
        html += infoRow('Source', (srcData.label || srcData.id));
        html += infoRow('Target', (tgtData.label || tgtData.id));
        document.getElementById('infoPanelBody').innerHTML = html;
    }

    function infoRow(label, value) {
        return '<div class="info-row"><span class="info-label">' + label + '</span><span class="info-value">' + value + '</span></div>';
    }

    // ── Stats ──
    function updateStats(elements) {
        var nodeCount, edgeCount;
        if (Array.isArray(elements)) {
            nodeCount = elements.filter(function(e) { return !e.data.source; }).length;
            edgeCount = elements.filter(function(e) { return !!e.data.source; }).length;
        } else {
            nodeCount = (elements.nodes || []).length;
            edgeCount = (elements.edges || []).length;
        }
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

        const isNode = selectedElement.isNode();
        const data = selectedElement.data();

        const url = isNode ? removeNodeUrl : removeEdgeUrl;
        const body = isNode
            ? { node_id: data.id }
            : { edge_id: data.id, from: data.source, to: data.target };

        apiPost(url, body).then(function(resp) {
            if (resp.success) {
                // Re-render with updated raw server data
                const elems = { nodes: resp.nodes, edges: resp.edges };
                initCytoscape(elems);
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
                const elems = { nodes: resp.nodes, edges: resp.edges };
                initCytoscape(elems);
                clearSelection();
            } else {
                alert(resp.error || 'Nothing to undo');
                document.getElementById('btnUndo').disabled = true;
            }
        }).catch(function(err) {
            alert('Network error: ' + err.message);
        });
    }

    // ── Layout ──
    function runLayout(name) {
        if (!cy) return;
        var nodeCount = cy.nodes().length;

        var opts;
        if (name === 'physics') {
            opts = getPhysicsLayoutOpts(nodeCount);
        } else {
            opts = { name: name, animate: true, animationDuration: 600, padding: 30 };
            if (name === 'cose') {
                opts.nodeRepulsion = function() { return 8000 * Math.max(1, nodeCount / 80); };
                opts.idealEdgeLength = function() { return Math.min(300, nodeCount * 0.6); };
            }
        }
        cy.layout(opts).run();
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
                    // Store raw elements then initialize (initCytoscape stores them too)
                    var elems = { nodes: data.nodes, edges: data.edges };
                    rawGraphElements = elems;
                    initCytoscape(elems);
                    document.getElementById('statFilename').textContent = data.filename || 'Loaded';
                } else {
                    // No graph in session - show placeholder
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
        if (cy) cy.resize();
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
        if (cy) cy.resize();
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
                if (cy) cy.resize();
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
                if (cy) cy.resize();
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
                if (cy) cy.resize();
            }
        });

        document.addEventListener('mouseup', function() {
            if (draggingV) {
                draggingV = false;
                handleV.classList.remove('active');
                document.body.classList.remove('resizing-v');
                if (cy) cy.resize();
            }
            if (draggingH) {
                draggingH = false;
                handleH.classList.remove('active');
                document.body.classList.remove('resizing-h');
                if (cy) { cy.resize(); cy.fit(undefined, 30); }
            }
            if (draggingBottom) {
                draggingBottom = false;
                handleBottom.classList.remove('active');
                document.body.classList.remove('resizing-h');
                if (cy) { cy.resize(); cy.fit(undefined, 30); }
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
            if (cy) cy.fit(undefined, 30);
        });
        document.getElementById('btnZoomIn').addEventListener('click', function() {
            if (cy) cy.zoom({ level: cy.zoom() * 1.3, renderedPosition: { x: cy.width() / 2, y: cy.height() / 2 } });
        });
        document.getElementById('btnZoomOut').addEventListener('click', function() {
            if (cy) cy.zoom({ level: cy.zoom() / 1.3, renderedPosition: { x: cy.width() / 2, y: cy.height() / 2 } });
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

        // Physics strength slider — live-update label; re-run layout on release
        var physicsSlider = document.getElementById('physicsStrength');
        var physicsVal = document.getElementById('physicsStrengthVal');
        if (physicsSlider) {
            physicsSlider.addEventListener('input', function() {
                physicsRepulsion = parseInt(this.value, 10);
                if (physicsVal) physicsVal.textContent = physicsRepulsion.toLocaleString();
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
            if (cy) cy.fit(undefined, 30);
        });

        // Initialize resizable drag handles
        initResizableHandles();

        // Load graph data on page load
        loadGraphFromServer();
    });

})();