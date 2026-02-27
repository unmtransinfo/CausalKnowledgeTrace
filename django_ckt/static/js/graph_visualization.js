/**
 * CKT Graph Visualization - Cytoscape.js Integration
 */
(function() {
    'use strict';

    let cy = null;
    let selectedElement = null;

    // ── Default Cytoscape style ──
    const cyStyle = [
        {
            selector: 'node',
            style: {
                'label': 'data(label)',
                'background-color': '#999',
                'color': '#333',
                'text-valign': 'bottom',
                'text-halign': 'center',
                'font-size': '10px',
                'text-margin-y': 4,
                'width': 28,
                'height': 28,
                'border-width': 1,
                'border-color': '#666',
                'text-max-width': '90px',
                'text-wrap': 'ellipsis',
            }
        },
        {
            selector: 'node[type="exposure"]',
            style: { 'background-color': '#2ecc71' }
        },
        {
            selector: 'node[type="outcome"]',
            style: { 'background-color': '#e74c3c' }
        },
        {
            selector: 'node:selected',
            style: {
                'border-width': 3,
                'border-color': '#ff0',
                'overlay-color': '#ff0',
                'overlay-opacity': 0.15,
            }
        },
        {
            selector: 'node.highlighted',
            style: {
                'border-width': 2,
                'border-color': '#00bcd4',
                'overlay-color': '#00bcd4',
                'overlay-opacity': 0.1,
            }
        },
        {
            selector: 'edge',
            style: {
                'width': 1.5,
                'line-color': '#999',
                'target-arrow-color': '#999',
                'target-arrow-shape': 'triangle',
                'curve-style': 'bezier',
                'arrow-scale': 0.8,
                'font-size': '8px',
                'text-rotation': 'autorotate',
                'text-background-color': '#fff',
                'text-background-opacity': 0.8,
                'text-background-padding': '2px',
            }
        },
        {
            selector: 'edge:selected',
            style: {
                'width': 3,
                'line-color': '#ff9800',
                'target-arrow-color': '#ff9800',
                'overlay-color': '#ff9800',
                'overlay-opacity': 0.15,
            }
        },
        {
            selector: 'edge.highlighted',
            style: {
                'width': 2.5,
                'line-color': '#00bcd4',
                'target-arrow-color': '#00bcd4',
            }
        },
        {
            selector: 'node.faded',
            style: { 'opacity': 0.2 }
        },
        {
            selector: 'edge.faded',
            style: { 'opacity': 0.1 }
        },
    ];

    // ── Initialize Cytoscape instance ──
    function initCytoscape(elements) {
        if (cy) { cy.destroy(); }

        document.getElementById('noGraphPlaceholder').style.display = 'none';
        document.getElementById('cy').style.display = 'block';

        cy = cytoscape({
            container: document.getElementById('cy'),
            elements: elements,
            style: cyStyle,
            layout: { name: 'cose', animate: true, animationDuration: 800, nodeRepulsion: function() { return 8000; }, idealEdgeLength: function() { return 80; }, padding: 30 },
            minZoom: 0.1,
            maxZoom: 5,
            wheelSensitivity: 0.3,
        });

        // Event bindings
        cy.on('tap', 'node', onNodeTap);
        cy.on('tap', 'edge', onEdgeTap);
        cy.on('tap', function(evt) {
            if (evt.target === cy) { clearSelection(); }
        });

        updateStats(elements);
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

        var nodeColor = data.type === 'exposure' ? '#2ecc71' : data.type === 'outcome' ? '#e74c3c' : '#999';
        let html = '<h6 style="margin:0 0 8px;color:var(--text-success)"><i class="fas fa-circle" style="color:' + nodeColor + '"></i> ' + (data.label || data.id) + '</h6>';
        html += infoRow('ID', data.id);
        html += infoRow('Type', data.type || '—');
        html += infoRow('Connections', connEdges.length + ' (' + incoming.length + ' in, ' + outgoing.length + ' out)');

        // List connected nodes
        if (connEdges.length > 0) {
            html += '<hr style="margin:8px 0">';
            html += '<strong style="font-size:0.83rem">Connected Nodes:</strong>';
            html += '<ul class="connected-list">';
            const neighbors = cy.getElementById(data.id).neighborhood().nodes();
            neighbors.forEach(function(n) {
                var nColor = n.data('type') === 'exposure' ? '#2ecc71' : n.data('type') === 'outcome' ? '#e74c3c' : '#999';
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
        const nodes = elements.nodes || elements.filter(function(e) { return e.group === 'nodes'; }) || [];
        const edges = elements.edges || elements.filter(function(e) { return e.group === 'edges'; }) || [];
        // Handle both {nodes:[], edges:[]} and flat array formats
        let nodeCount, edgeCount;
        if (Array.isArray(elements)) {
            nodeCount = elements.filter(function(e) { return !e.data.source; }).length;
            edgeCount = elements.filter(function(e) { return e.data.source; }).length;
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
                // Re-render with updated data
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
        const opts = { name: name, animate: true, animationDuration: 600, padding: 30 };
        if (name === 'cose') {
            opts.nodeRepulsion = function() { return 8000; };
            opts.idealEdgeLength = function() { return 80; };
        }
        cy.layout(opts).run();
    }

    // ── Load graph from server ──
    function loadGraphFromServer() {
        fetch(networkDataUrl)
            .then(function(r) { return r.json(); })
            .then(function(data) {
                if (data.success && data.nodes && data.nodes.length > 0) {
                    const elems = { nodes: data.nodes, edges: data.edges };
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