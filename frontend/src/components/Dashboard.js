import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Container,
  Grid,
  Paper,
  Typography,
  Box,
  Card,
  CardContent,
  CardActions,
  Button,
  Alert,
  CircularProgress,
} from '@mui/material';
import { Add, Inventory, Search, History } from '@mui/icons-material';
import { useAuth } from '../context/AuthContext';
import { contractAPI } from '../services/api';

const Dashboard = () => {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [stats, setStats] = useState({
    totalProducts: 0,
    recentProducts: [],
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      setLoading(true);
      const response = await contractAPI.getListSanPham();
      if (response.data && response.data.success) {
        const products = response.data.message || [];
        setStats({
          totalProducts: products.length,
          recentProducts: products.slice(0, 5), // Show last 5 products
        });
      }
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
      setError('Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };

  const quickActions = [
    {
      title: 'Create Product',
      description: 'Add a new product to the blockchain',
      icon: <Add fontSize="large" />,
      action: () => navigate('/products/create'),
      color: 'primary',
    },
    {
      title: 'View Products',
      description: 'Browse all products',
      icon: <Inventory fontSize="large" />,
      action: () => navigate('/products'),
      color: 'secondary',
    },
    {
      title: 'Search Products',
      description: 'Search for specific products',
      icon: <Search fontSize="large" />,
      action: () => navigate('/products'),
      color: 'info',
    },
  ];

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
      <Typography variant="h4" gutterBottom>
        Welcome, {user?.displayname || user?.username}!
      </Typography>
      
      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}

      <Grid container spacing={3}>
        {/* Stats Cards */}
        <Grid item xs={12} md={4}>
          <Paper
            sx={{
              p: 2,
              display: 'flex',
              flexDirection: 'column',
              height: 140,
              background: 'linear-gradient(45deg, #FE6B8B 30%, #FF8E53 90%)',
              color: 'white',
            }}
          >
            <Typography variant="h6" gutterBottom>
              Total Products
            </Typography>
            <Typography variant="h3" sx={{ flexGrow: 1 }}>
              {stats.totalProducts}
            </Typography>
          </Paper>
        </Grid>

        <Grid item xs={12} md={4}>
          <Paper
            sx={{
              p: 2,
              display: 'flex',
              flexDirection: 'column',
              height: 140,
              background: 'linear-gradient(45deg, #2196F3 30%, #21CBF3 90%)',
              color: 'white',
            }}
          >
            <Typography variant="h6" gutterBottom>
              Your Organization
            </Typography>
            <Typography variant="h4" sx={{ flexGrow: 1 }}>
              {user?.msp}
            </Typography>
          </Paper>
        </Grid>

        <Grid item xs={12} md={4}>
          <Paper
            sx={{
              p: 2,
              display: 'flex',
              flexDirection: 'column',
              height: 140,
              background: 'linear-gradient(45deg, #4CAF50 30%, #8BC34A 90%)',
              color: 'white',
            }}
          >
            <Typography variant="h6" gutterBottom>
              Status
            </Typography>
            <Typography variant="h4" sx={{ flexGrow: 1 }}>
              Active
            </Typography>
          </Paper>
        </Grid>

        {/* Quick Actions */}
        <Grid item xs={12}>
          <Typography variant="h5" gutterBottom sx={{ mt: 2 }}>
            Quick Actions
          </Typography>
          <Grid container spacing={2}>
            {quickActions.map((action, index) => (
              <Grid item xs={12} md={4} key={index}>
                <Card sx={{ height: '100%' }}>
                  <CardContent sx={{ textAlign: 'center' }}>
                    <Box sx={{ color: `${action.color}.main`, mb: 2 }}>
                      {action.icon}
                    </Box>
                    <Typography variant="h6" gutterBottom>
                      {action.title}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      {action.description}
                    </Typography>
                  </CardContent>
                  <CardActions sx={{ justifyContent: 'center' }}>
                    <Button
                      size="small"
                      variant="contained"
                      color={action.color}
                      onClick={action.action}
                    >
                      Go
                    </Button>
                  </CardActions>
                </Card>
              </Grid>
            ))}
          </Grid>
        </Grid>

        {/* Recent Products */}
        <Grid item xs={12}>
          <Typography variant="h5" gutterBottom sx={{ mt: 2 }}>
            Recent Products
          </Typography>
          <Paper sx={{ p: 2 }}>
            {stats.recentProducts.length > 0 ? (
              <Grid container spacing={2}>
                {stats.recentProducts.map((product, index) => (
                  <Grid item xs={12} md={6} key={index}>
                    <Card>
                      <CardContent>
                        <Typography variant="h6" gutterBottom>
                          {product.tensanpham || 'Product Name'}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                          ID: {product.id || 'N/A'}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                          Created: {product.thoigian || 'N/A'}
                        </Typography>
                      </CardContent>
                      <CardActions>
                        <Button
                          size="small"
                          onClick={() => navigate(`/products/${product.id}`)}
                        >
                          View Details
                        </Button>
                      </CardActions>
                    </Card>
                  </Grid>
                ))}
              </Grid>
            ) : (
              <Typography variant="body1" color="text.secondary">
                No products found. Create your first product!
              </Typography>
            )}
          </Paper>
        </Grid>
      </Grid>
    </Container>
  );
};

export default Dashboard;
