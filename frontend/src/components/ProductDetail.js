import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  Container,
  Paper,
  Typography,
  Box,
  Button,
  Grid,
  Card,
  CardContent,
  Alert,
  CircularProgress,
  Chip,
  Divider,
  List,
  ListItem,
  ListItemText,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
} from '@mui/material';
import {
  ArrowBack,
  Edit,
  History,
  Package,
  Transform,
  Security,
} from '@mui/icons-material';
import { contractAPI } from '../services/api';

const ProductDetail = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const [product, setProduct] = useState(null);
  const [history, setHistory] = useState([]);
  const [hashValue, setHashValue] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [historyDialog, setHistoryDialog] = useState(false);
  const [updateDialog, setUpdateDialog] = useState(false);
  const [transferDialog, setTransferDialog] = useState(false);
  const [updateData, setUpdateData] = useState({});
  const [transferData, setTransferData] = useState({
    recipient: '',
    reason: '',
  });

  useEffect(() => {
    if (id) {
      fetchProductDetails();
      fetchProductHistory();
      fetchHashValue();
    }
  }, [id]);

  const fetchProductDetails = async () => {
    try {
      setLoading(true);
      const response = await contractAPI.getById(id);
      if (response.data && response.data.success) {
        setProduct(response.data.message);
        setUpdateData(response.data.message);
      } else {
        setError('Product not found');
      }
    } catch (error) {
      console.error('Error fetching product details:', error);
      setError('Failed to fetch product details');
    } finally {
      setLoading(false);
    }
  };

  const fetchProductHistory = async () => {
    try {
      const response = await contractAPI.getHistory(id);
      if (response.data && response.data.success) {
        setHistory(response.data.message || []);
      }
    } catch (error) {
      console.error('Error fetching product history:', error);
    }
  };

  const fetchHashValue = async () => {
    try {
      const response = await contractAPI.getHashValue(id);
      if (response.data && response.data.success) {
        setHashValue(response.data.message);
      }
    } catch (error) {
      console.error('Error fetching hash value:', error);
    }
  };

  const handleUpdate = async () => {
    try {
      const response = await contractAPI.update(updateData);
      if (response.data && response.data.success) {
        setUpdateDialog(false);
        fetchProductDetails();
        alert('Product updated successfully!');
      } else {
        alert('Failed to update product');
      }
    } catch (error) {
      console.error('Error updating product:', error);
      alert('Failed to update product');
    }
  };

  const handleTransfer = async () => {
    try {
      const response = await contractAPI.transfer({
        id: id,
        ...transferData,
      });
      if (response.data && response.data.success) {
        setTransferDialog(false);
        fetchProductDetails();
        alert('Product transferred successfully!');
      } else {
        alert('Failed to transfer product');
      }
    } catch (error) {
      console.error('Error transferring product:', error);
      alert('Failed to transfer product');
    }
  };

  if (loading) {
    return (
      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Box display="flex" justifyContent="center" alignItems="center" minHeight="200px">
          <CircularProgress />
        </Box>
      </Container>
    );
  }

  if (error) {
    return (
      <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
        <Alert severity="error">{error}</Alert>
      </Container>
    );
  }

  return (
    <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
      <Box display="flex" alignItems="center" mb={3}>
        <Button
          startIcon={<ArrowBack />}
          onClick={() => navigate('/products')}
          sx={{ mr: 2 }}
        >
          Back to Products
        </Button>
        <Typography variant="h4">
          {product?.tensanpham || 'Product Details'}
        </Typography>
      </Box>

      <Grid container spacing={3}>
        {/* Product Information */}
        <Grid item xs={12} md={8}>
          <Paper sx={{ p: 3, mb: 3 }}>
            <Typography variant="h6" gutterBottom>
              Product Information
            </Typography>
            <Divider sx={{ mb: 2 }} />
            <Grid container spacing={2}>
              <Grid item xs={12} md={6}>
                <Typography variant="body2" color="text.secondary">
                  Product ID
                </Typography>
                <Typography variant="body1" gutterBottom>
                  {product?.id || 'N/A'}
                </Typography>
              </Grid>
              <Grid item xs={12} md={6}>
                <Typography variant="body2" color="text.secondary">
                  Product Name
                </Typography>
                <Typography variant="body1" gutterBottom>
                  {product?.tensanpham || 'N/A'}
                </Typography>
              </Grid>
              <Grid item xs={12} md={6}>
                <Typography variant="body2" color="text.secondary">
                  Manufacturer
                </Typography>
                <Typography variant="body1" gutterBottom>
                  {product?.nhasanxuat || 'N/A'}
                </Typography>
              </Grid>
              <Grid item xs={12} md={6}>
                <Typography variant="body2" color="text.secondary">
                  Date
                </Typography>
                <Typography variant="body1" gutterBottom>
                  {product?.thoigian || 'N/A'}
                </Typography>
              </Grid>
              <Grid item xs={12} md={6}>
                <Typography variant="body2" color="text.secondary">
                  Location
                </Typography>
                <Typography variant="body1" gutterBottom>
                  {product?.diadiem || 'N/A'}
                </Typography>
              </Grid>
              <Grid item xs={12} md={6}>
                <Typography variant="body2" color="text.secondary">
                  Coordinates
                </Typography>
                <Typography variant="body1" gutterBottom>
                  {product?.toado || 'N/A'}
                </Typography>
              </Grid>
              <Grid item xs={12}>
                <Typography variant="body2" color="text.secondary">
                  Status
                </Typography>
                <Chip
                  label={product?.trangthai || 'Unknown'}
                  color={product?.trangthai === 'active' ? 'success' : 'default'}
                  sx={{ mb: 2 }}
                />
              </Grid>
              <Grid item xs={12}>
                <Typography variant="body2" color="text.secondary">
                  Description
                </Typography>
                <Typography variant="body1">
                  {product?.mota || 'No description available'}
                </Typography>
              </Grid>
            </Grid>
          </Paper>
        </Grid>

        {/* Actions */}
        <Grid item xs={12} md={4}>
          <Paper sx={{ p: 3, mb: 3 }}>
            <Typography variant="h6" gutterBottom>
              Actions
            </Typography>
            <Divider sx={{ mb: 2 }} />
            <Box display="flex" flexDirection="column" gap={2}>
              <Button
                variant="outlined"
                startIcon={<Edit />}
                onClick={() => setUpdateDialog(true)}
                fullWidth
              >
                Update Product
              </Button>
              <Button
                variant="outlined"
                startIcon={<Transform />}
                onClick={() => setTransferDialog(true)}
                fullWidth
              >
                Transfer Product
              </Button>
              <Button
                variant="outlined"
                startIcon={<History />}
                onClick={() => setHistoryDialog(true)}
                fullWidth
              >
                View History
              </Button>
            </Box>
          </Paper>

          {/* Hash Value */}
          <Paper sx={{ p: 3 }}>
            <Typography variant="h6" gutterBottom>
              <Security sx={{ mr: 1 }} />
              Security Hash
            </Typography>
            <Divider sx={{ mb: 2 }} />
            <Typography
              variant="body2"
              sx={{
                wordBreak: 'break-all',
                fontFamily: 'monospace',
                backgroundColor: 'grey.100',
                p: 1,
                borderRadius: 1,
              }}
            >
              {hashValue || 'No hash available'}
            </Typography>
          </Paper>
        </Grid>
      </Grid>

      {/* History Dialog */}
      <Dialog open={historyDialog} onClose={() => setHistoryDialog(false)} maxWidth="md" fullWidth>
        <DialogTitle>Product History</DialogTitle>
        <DialogContent>
          {history.length > 0 ? (
            <List>
              {history.map((item, index) => (
                <ListItem key={index} divider>
                  <ListItemText
                    primary={`Transaction ${index + 1}`}
                    secondary={JSON.stringify(item, null, 2)}
                  />
                </ListItem>
              ))}
            </List>
          ) : (
            <Typography>No history available</Typography>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setHistoryDialog(false)}>Close</Button>
        </DialogActions>
      </Dialog>

      {/* Update Dialog */}
      <Dialog open={updateDialog} onClose={() => setUpdateDialog(false)} maxWidth="md" fullWidth>
        <DialogTitle>Update Product</DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Product Name"
                value={updateData.tensanpham || ''}
                onChange={(e) => setUpdateData({ ...updateData, tensanpham: e.target.value })}
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Description"
                multiline
                rows={3}
                value={updateData.mota || ''}
                onChange={(e) => setUpdateData({ ...updateData, mota: e.target.value })}
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setUpdateDialog(false)}>Cancel</Button>
          <Button onClick={handleUpdate} variant="contained">Update</Button>
        </DialogActions>
      </Dialog>

      {/* Transfer Dialog */}
      <Dialog open={transferDialog} onClose={() => setTransferDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Transfer Product</DialogTitle>
        <DialogContent>
          <Grid container spacing={2} sx={{ mt: 1 }}>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Recipient"
                value={transferData.recipient}
                onChange={(e) => setTransferData({ ...transferData, recipient: e.target.value })}
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                fullWidth
                label="Reason"
                multiline
                rows={2}
                value={transferData.reason}
                onChange={(e) => setTransferData({ ...transferData, reason: e.target.value })}
              />
            </Grid>
          </Grid>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setTransferDialog(false)}>Cancel</Button>
          <Button onClick={handleTransfer} variant="contained">Transfer</Button>
        </DialogActions>
      </Dialog>
    </Container>
  );
};

export default ProductDetail;
