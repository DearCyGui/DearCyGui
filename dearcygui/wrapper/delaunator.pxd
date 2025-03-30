from libcpp.vector cimport vector
from libcpp cimport bool

cdef extern from * nogil:
    """
    #include "delaunator.hpp"
    #include "Constrainautor.hpp"
    #include <unordered_set>

    struct DelaunationResult {
        std::vector<size_t> hull_indices;
        std::vector<size_t> hull_triangles;
        std::vector<size_t> polygon_triangles;
        bool constrained_success;
    };

    inline DelaunationResult delaunator_get_triangles(const std::vector<double>& coords) {
        DelaunationResult result;
        result.constrained_success = false;

        // Create initial triangulation
        delaunator::Delaunator d(coords);

        // Get hull indices
        size_t e = d.hull_start;
        do {
            result.hull_indices.push_back(e);
            e = d.hull_next[e];
        } while (e != d.hull_start);

        // Get hull triangulation (all triangles for now)
        result.hull_triangles = d.triangles;

        try {
            // Create edge constraints for the polygon from the original coordinate sequence
            // We assume coords contains an ordered sequence of polygon vertices
            std::vector<std::pair<size_t, size_t>> constraints;
            const size_t num_points = coords.size() / 2;
            
            // Create constraint edges between consecutive vertices
            for (size_t i = 0; i < num_points; i++) {
                size_t next = (i + 1) % num_points;
                // Convert from point indices to Delaunator vertex indices
                constraints.push_back({i, next});
            }

            // Apply constraints
            constrainautor::Constrainautor c(d);
            c.constrainAll(constraints);
            result.constrained_success = true;

            // Mark boundary edges
            std::unordered_set<size_t> boundary_edges;
            std::unordered_set<size_t> boundary_triangles;
            
            /* -> does not work because it seems the halfedges
            * for the contrained edges are not set correctly
            for (const auto& constraint : constraints) {
                int edge = c.findEdge(constraint.first, constraint.second);
                if (edge >= 0) {
                    size_t e = edge;
                    boundary_edges.insert(e);
                    boundary_triangles.insert(e / 3); // Triangle containing this edge
                    
                    // Check for opposing half-edge
                    size_t opposite = d.halfedges[e];
                    if (opposite != delaunator::INVALID_INDEX) {
                        boundary_edges.insert(opposite);
                        boundary_triangles.insert(opposite / 3); // Triangle on other side
                    }
                }
            }*/
            for (const auto& constraint : constraints) {
                // Find both directions of the edge
                int edge1 = c.findEdge(constraint.first, constraint.second);
                int edge2 = c.findEdge(constraint.second, constraint.first);
                
                if (edge1 >= 0) {
                    size_t e = edge1;
                    boundary_edges.insert(e);
                    boundary_triangles.insert(e / 3);
                }
                
                if (edge2 >= 0) {
                    size_t e = edge2;
                    boundary_edges.insert(e);
                    boundary_triangles.insert(e / 3);
                }
            }
            
            // If we have boundary triangles, pick the first one to start flood fills
            if (!boundary_triangles.empty()) {
                size_t start_edge = *boundary_edges.begin();
                size_t tri1 = start_edge / 3;
                size_t tri2 = delaunator::INVALID_INDEX;
                
                // If there's a triangle on the other side of this edge, get its index
                size_t opposite = d.halfedges[start_edge];
                if (opposite != delaunator::INVALID_INDEX) {
                    tri2 = opposite / 3;
                }
                
                // Try both possible starting triangles and pick the better result
                std::vector<size_t> result1;
                std::vector<size_t> result2;
                std::vector<bool> visited1(d.triangles.size() / 3, false);
                std::vector<bool> visited2(d.triangles.size() / 3, false);
                
                // First flood fill
                {
                    std::vector<size_t> stack;
                    stack.push_back(tri1);
                    
                    while (!stack.empty()) {
                        size_t tri = stack.back();
                        stack.pop_back();
                        
                        if (visited1[tri]) continue;
                        visited1[tri] = true;
                        
                        // Add triangle to result regardless of whether it's a boundary triangle
                        result1.push_back(d.triangles[tri * 3]);
                        result1.push_back(d.triangles[tri * 3 + 1]);
                        result1.push_back(d.triangles[tri * 3 + 2]);
                        
                        // Add adjacent triangles to stack, but don't cross boundary edges
                        for (size_t i = 0; i < 3; i++) {
                            size_t edge = tri * 3 + i;
                            // Skip if this is a boundary edge
                            if (boundary_edges.count(edge) > 0) continue;
                            
                            size_t opposite = d.halfedges[edge];
                            if (opposite != delaunator::INVALID_INDEX) {
                                size_t adj_tri = opposite / 3;
                                if (!visited1[adj_tri]) {
                                    stack.push_back(adj_tri);
                                }
                            }
                        }
                    }
                }
                
                // Second flood fill (if there's another triangle)
                if (tri2 != delaunator::INVALID_INDEX) {
                    std::vector<size_t> stack;
                    stack.push_back(tri2);
                    
                    while (!stack.empty()) {
                        size_t tri = stack.back();
                        stack.pop_back();
                        
                        if (visited2[tri]) continue;
                        visited2[tri] = true;
                        
                        // Add triangle to result regardless of whether it's a boundary triangle
                        result2.push_back(d.triangles[tri * 3]);
                        result2.push_back(d.triangles[tri * 3 + 1]);
                        result2.push_back(d.triangles[tri * 3 + 2]);
                        
                        // Add adjacent triangles to stack, but don't cross boundary edges
                        for (size_t i = 0; i < 3; i++) {
                            size_t edge = tri * 3 + i;
                            // Skip if this is a boundary edge
                            if (boundary_edges.count(edge) > 0) continue;
                            
                            size_t opposite = d.halfedges[edge];
                            if (opposite != delaunator::INVALID_INDEX) {
                                size_t adj_tri = opposite / 3;
                                if (!visited2[adj_tri]) {
                                    stack.push_back(adj_tri);
                                }
                            }
                        }
                    }
                }
                
                // Count how many edges of the polygon are present in each result
                // Count boundary edges adjacent to triangles in each result
                size_t result1_boundary_edge_count = 0;
                size_t result2_boundary_edge_count = 0;

                // For result1, count boundary edges
                for (size_t i = 0; i < visited1.size(); i++) {
                    if (visited1[i]) {
                        for (size_t j = 0; j < 3; j++) {
                            size_t edge_idx = i * 3 + j;
                            if (boundary_edges.count(edge_idx) > 0) {
                                result1_boundary_edge_count++;
                            }
                        }
                    }
                }

                // For result2, count boundary edges
                for (size_t i = 0; i < visited2.size(); i++) {
                    if (visited2[i]) {
                        for (size_t j = 0; j < 3; j++) {
                            size_t edge_idx = i * 3 + j;
                            if (boundary_edges.count(edge_idx) > 0) {
                                result2_boundary_edge_count++;
                            }
                        }
                    }
                }

                // Choose the result with more boundary edges
                if (result2.empty() || result1_boundary_edge_count >= result2_boundary_edge_count) {
                    result.polygon_triangles = std::move(result1);
                } else {
                    result.polygon_triangles = std::move(result2);
                }
            }
        } catch (const std::exception& e) {
            result.constrained_success = false;
            result.polygon_triangles.clear();
        }

        return result;
    }
    """
    cdef struct DelaunationResult:
        vector[size_t] hull_indices
        vector[size_t] hull_triangles
        vector[size_t] polygon_triangles
        bool constrained_success

    DelaunationResult delaunator_get_triangles(const vector[double]& coords) except +