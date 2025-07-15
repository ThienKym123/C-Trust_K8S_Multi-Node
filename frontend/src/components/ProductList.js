import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Container,
  Typography,
  Box,
  Card,
  CardContent,
  CardActions,
  Button,
  Grid,
  TextField,
  Alert,
  CircularProgress,
  Chip,
  InputAdornment,
  Pagination,
} from '@mui/material';
import { Search, Add, Visibility } from '@mui/icons-material';
import { contractAPI } from '../services/api';

const ProductList = () => {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [searchTerm, setSearchTerm] = useState('');
  const [filteredProducts, setFilteredProducts] = useState([]);
  const [page, setPage] = useState(1);
  const [itemsPerPage] = useState(12);
  const navigate = useNavigate();

  useEffect(() => {
    fetchProducts();
  }, []);

  useEffect(() => {
    // Filter products based on search term
    if (searchTerm) {
      const filtered = products.filter(product =>
        product.tensanpham?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        product.id?.toLowerCase().includes(searchTerm.toLowerCase()) ||
        product.nhasanxuat?.toLowerCase().includes(searchTerm.toLowerCase())
      );
      setFilteredProducts(filtered);
    } else {
      setFilteredProducts(products);
    }
    setPage(1); // Reset to first page when searching
  }, [searchTerm, products]);

  const fetchProducts = async () => {
    try {
      setLoading(true);
      const response = await contractAPI.getListSanPham();
      if (response.data && response.data.success) {
        const productList = response.data.message || [];
        setProducts(productList);
        setFilteredProducts(productList);
      } else {
        setError('Failed to fetch products');
      }
    } catch (error) {
      console.error('Error fetching products:', error);
      setError('Failed to fetch products');
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = async () => {
    if (searchTerm.trim()) {
      try {
        setLoading(true);
        const response = await contractAPI.searchSanPham(searchTerm);
        if (response.data && response.data.success) {
          const searchResults = response.data.message || [];
          setFilteredProducts(searchResults);
        }
      } catch (error) {
        console.error('Error searching products:', error);
        setError('Failed to search products');
      } finally {
        setLoading(false);
      }
    } else {
      setFilteredProducts(products);
    }
  };

  const handlePageChange = (event, value) => {
    setPage(value);
  };

  const paginatedProducts = filteredProducts.slice(
    (page - 1) * itemsPerPage,
    page * itemsPerPage
  );

  if (loading) {
    return (
      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Box display="flex" justifyContent="center" alignItems="center" minHeight="200px">
          <CircularProgress />
        </Box>
      </Container>
    );
  }

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4" gutterBottom>
          Products
        </Typography>
        <Button
          variant="contained"
          startIcon={<Add />}
          onClick={() => navigate('/products/create')}
        >
          Create Product
        </Button>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}

      {/* Search Bar */}
      <Box sx={{ mb: 3 }}>
        <TextField
          fullWidth
          variant="outlined"
          placeholder="Search products by name, ID, or manufacturer..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <Search />
              </InputAdornment>
            ),
            endAdornment: (
              <InputAdornment position="end">
                <Button
                  variant="contained"
                  size="small"
                  onClick={handleSearch}
                  sx={{ mr: -1 }}
                >
                  Search
                </Button>
              </InputAdornment>
            ),
          }}
        />
      </Box>

      {/* Products Grid */}
      {filteredProducts.length > 0 ? (
        <>
          <Grid container spacing={3}>
            {paginatedProducts.map((product, index) => (
              <Grid item xs={12} sm={6} md={4} key={product.id || index}>
                <Card sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
                  <CardContent sx={{ flexGrow: 1 }}>
                    <Typography variant="h6" gutterBottom>
                      {product.tensanpham || 'Unknown Product'}
                    </Typography>
                    <Typography variant="body2" color="text.secondary" gutterBottom>
                      ID: {product.id || 'N/A'}
                    </Typography>
                    <Typography variant="body2" color="text.secondary" gutterBottom>
                      Manufacturer: {product.nhasanxuat || 'N/A'}
                    </Typography>
                    <Typography variant="body2" color="text.secondary" gutterBottom>
                      Location: {product.diadiem || 'N/A'}
                    </Typography>
                    <Typography variant="body2" color="text.secondary" gutterBottom>
                      Time: {product.thoigian || 'N/A'}
                    </Typography>
                    {product.trangthai && (
                      <Chip
                        label={product.trangthai}
                        color={product.trangthai === 'active' ? 'success' : 'default'}
                        size="small"
                        sx={{ mt: 1 }}
                      />
                    )}
                    {product.mota && (
                      <Typography variant="body2" sx={{ mt: 1 }}>
                        {product.mota.length > 100 
                          ? `${product.mota.substring(0, 100)}...` 
                          : product.mota}
                      </Typography>
                    )}
                  </CardContent>
                  <CardActions>
                    <Button
                      size="small"
                      startIcon={<Visibility />}
                      onClick={() => navigate(`/products/${product.id}`)}
                    >
                      View Details
                    </Button>
                  </CardActions>
                </Card>
              </Grid>
            ))}
          </Grid>

          {/* Pagination */}
          {filteredProducts.length > itemsPerPage && (
            <Box display="flex" justifyContent="center" mt={4}>
              <Pagination
                count={Math.ceil(filteredProducts.length / itemsPerPage)}
                page={page}
                onChange={handlePageChange}
                color="primary"
              />
            </Box>
          )}
        </>
      ) : (
        <Box textAlign="center" py={4}>
          <Typography variant="h6" color="text.secondary">
            No products found
          </Typography>
          <Typography variant="body1" color="text.secondary" sx={{ mt: 1 }}>
            {searchTerm ? 'Try adjusting your search terms' : 'Create your first product to get started'}
          </Typography>
          <Button
            variant="contained"
            startIcon={<Add />}
            onClick={() => navigate('/products/create')}
            sx={{ mt: 2 }}
          >
            Create Product
          </Button>
        </Box>
      )}
    </Container>
  );
};

export default ProductList;
