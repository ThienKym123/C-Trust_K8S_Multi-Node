import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Container,
  Paper,
  Typography,
  Box,
  TextField,
  Button,
  Alert,
  CircularProgress,
  FormControl,
  InputLabel,
  Select,
  MenuItem,
  Grid,
} from '@mui/material';
import { AdminPanelSettings, PersonAdd } from '@mui/icons-material';
import { useAuth } from '../context/AuthContext';

const AdminPanel = () => {
  const [adminData, setAdminData] = useState({
    username: '',
    password: '',
    msp: 'Org1MSP',
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const { enrollAdmin } = useAuth();
  const navigate = useNavigate();

  const handleChange = (e) => {
    setAdminData({
      ...adminData,
      [e.target.name]: e.target.value,
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setSuccess('');

    try {
      const result = await enrollAdmin(adminData);
      if (result.success) {
        setSuccess('Admin enrolled successfully!');
        setTimeout(() => {
          navigate('/login');
        }, 2000);
      } else {
        setError(result.error);
      }
    } catch (error) {
      setError('An unexpected error occurred');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Container component="main" maxWidth="sm">
      <Box
        sx={{
          marginTop: 8,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
        }}
      >
        <Paper elevation={3} sx={{ padding: 4, width: '100%' }}>
          <Box display="flex" alignItems="center" justifyContent="center" mb={3}>
            <AdminPanelSettings sx={{ mr: 2, fontSize: 40, color: 'primary.main' }} />
            <Typography component="h1" variant="h4" align="center">
              Admin Panel
            </Typography>
          </Box>
          
          <Typography variant="h6" align="center" gutterBottom>
            Enroll Admin User
          </Typography>

          {error && (
            <Alert severity="error" sx={{ mb: 2 }}>
              {error}
            </Alert>
          )}

          {success && (
            <Alert severity="success" sx={{ mb: 2 }}>
              {success}
            </Alert>
          )}

          <Box component="form" onSubmit={handleSubmit} sx={{ mt: 1 }}>
            <Grid container spacing={2}>
              <Grid item xs={12}>
                <TextField
                  margin="normal"
                  required
                  fullWidth
                  id="username"
                  label="Admin Username"
                  name="username"
                  autoComplete="username"
                  autoFocus
                  value={adminData.username}
                  onChange={handleChange}
                />
              </Grid>
              <Grid item xs={12}>
                <TextField
                  margin="normal"
                  required
                  fullWidth
                  name="password"
                  label="Admin Password"
                  type="password"
                  id="password"
                  autoComplete="current-password"
                  value={adminData.password}
                  onChange={handleChange}
                />
              </Grid>
              <Grid item xs={12}>
                <FormControl fullWidth margin="normal">
                  <InputLabel id="msp-label">Organization</InputLabel>
                  <Select
                    labelId="msp-label"
                    id="msp"
                    name="msp"
                    value={adminData.msp}
                    label="Organization"
                    onChange={handleChange}
                  >
                    <MenuItem value="Org1MSP">Org1MSP</MenuItem>
                    <MenuItem value="Org2MSP">Org2MSP</MenuItem>
                  </Select>
                </FormControl>
              </Grid>
            </Grid>
            
            <Button
              type="submit"
              fullWidth
              variant="contained"
              startIcon={<PersonAdd />}
              sx={{ mt: 3, mb: 2 }}
              disabled={loading}
            >
              {loading ? <CircularProgress size={24} /> : 'Enroll Admin'}
            </Button>
            
            <Box display="flex" justifyContent="center">
              <Button
                variant="text"
                onClick={() => navigate('/login')}
                sx={{ mt: 1 }}
              >
                Back to Login
              </Button>
            </Box>
          </Box>

          <Box sx={{ mt: 4, p: 2, backgroundColor: 'grey.100', borderRadius: 1 }}>
            <Typography variant="body2" color="text.secondary">
              <strong>Note:</strong> This panel is used to enroll admin users for the Hyperledger Fabric network. 
              Only use this if you need to set up initial admin credentials for the blockchain network.
            </Typography>
          </Box>
        </Paper>
      </Box>
    </Container>
  );
};

export default AdminPanel;
