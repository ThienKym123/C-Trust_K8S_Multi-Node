import React, { useState, useEffect } from 'react';
import {
  Container,
  Paper,
  Typography,
  Box,
  TextField,
  Button,
  Grid,
  Avatar,
  Alert,
  CircularProgress,
  Divider,
} from '@mui/material';
import { Save, Edit, Person } from '@mui/icons-material';
import { useAuth } from '../context/AuthContext';
import { userAPI } from '../services/api';

const UserProfile = () => {
  const { user, logout } = useAuth();
  const [userDetails, setUserDetails] = useState(null);
  const [editMode, setEditMode] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [formData, setFormData] = useState({
    displayname: '',
    phonenumber: '',
    address: '',
    description: '',
  });

  useEffect(() => {
    fetchUserDetails();
  }, []);

  const fetchUserDetails = async () => {
    try {
      setLoading(true);
      const response = await userAPI.getUser();
      if (response.data && response.data.success) {
        const userData = response.data.message;
        setUserDetails(userData);
        setFormData({
          displayname: userData.displayname || '',
          phonenumber: userData.phonenumber || '',
          address: userData.address || '',
          description: userData.description || '',
        });
      } else {
        setError('Failed to fetch user details');
      }
    } catch (error) {
      console.error('Error fetching user details:', error);
      setError('Failed to fetch user details');
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value,
    });
  };

  const handleSave = async () => {
    try {
      setSaving(true);
      setError('');
      setSuccess('');

      const response = await userAPI.editProfile(formData);
      if (response.data && response.data.success) {
        setSuccess('Profile updated successfully!');
        setEditMode(false);
        fetchUserDetails();
      } else {
        setError('Failed to update profile');
      }
    } catch (error) {
      console.error('Error updating profile:', error);
      setError('Failed to update profile');
    } finally {
      setSaving(false);
    }
  };

  const handleRevokeUser = async () => {
    if (window.confirm('Are you sure you want to revoke this user? This action cannot be undone.')) {
      try {
        const response = await userAPI.revokeUser({ username: user.username });
        if (response.data && response.data.success) {
          alert('User revoked successfully');
          logout();
        } else {
          alert('Failed to revoke user');
        }
      } catch (error) {
        console.error('Error revoking user:', error);
        alert('Failed to revoke user');
      }
    }
  };

  const handleReenrollUser = async () => {
    if (window.confirm('Are you sure you want to re-enroll this user?')) {
      try {
        const response = await userAPI.reenrollUser({ username: user.username });
        if (response.data && response.data.success) {
          alert('User re-enrolled successfully');
          fetchUserDetails();
        } else {
          alert('Failed to re-enroll user');
        }
      } catch (error) {
        console.error('Error re-enrolling user:', error);
        alert('Failed to re-enroll user');
      }
    }
  };

  if (loading) {
    return (
      <Container maxWidth="md" sx={{ mt: 4, mb: 4 }}>
        <Box display="flex" justifyContent="center" alignItems="center" minHeight="200px">
          <CircularProgress />
        </Box>
      </Container>
    );
  }

  return (
    <Container maxWidth="md" sx={{ mt: 4, mb: 4 }}>
      <Paper elevation={3} sx={{ p: 4 }}>
        <Box display="flex" alignItems="center" mb={3}>
          <Avatar sx={{ width: 80, height: 80, mr: 3, bgcolor: 'primary.main' }}>
            <Person sx={{ fontSize: 40 }} />
          </Avatar>
          <Box>
            <Typography variant="h4" gutterBottom>
              {userDetails?.displayname || user?.displayname || user?.username}
            </Typography>
            <Typography variant="h6" color="text.secondary">
              {user?.msp}
            </Typography>
          </Box>
        </Box>

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

        <Divider sx={{ mb: 3 }} />

        <Grid container spacing={3}>
          <Grid item xs={12} md={6}>
            <TextField
              fullWidth
              label="Username"
              value={user?.username || ''}
              disabled
              sx={{ mb: 2 }}
            />
          </Grid>
          <Grid item xs={12} md={6}>
            <TextField
              fullWidth
              label="User ID"
              value={user?.userId || userDetails?.userId || ''}
              disabled
              sx={{ mb: 2 }}
            />
          </Grid>
          <Grid item xs={12} md={6}>
            <TextField
              fullWidth
              label="Display Name"
              name="displayname"
              value={formData.displayname}
              onChange={handleChange}
              disabled={!editMode}
              sx={{ mb: 2 }}
            />
          </Grid>
          <Grid item xs={12} md={6}>
            <TextField
              fullWidth
              label="Phone Number"
              name="phonenumber"
              value={formData.phonenumber}
              onChange={handleChange}
              disabled={!editMode}
              sx={{ mb: 2 }}
            />
          </Grid>
          <Grid item xs={12}>
            <TextField
              fullWidth
              label="Address"
              name="address"
              value={formData.address}
              onChange={handleChange}
              disabled={!editMode}
              multiline
              rows={2}
              sx={{ mb: 2 }}
            />
          </Grid>
          <Grid item xs={12}>
            <TextField
              fullWidth
              label="Description"
              name="description"
              value={formData.description}
              onChange={handleChange}
              disabled={!editMode}
              multiline
              rows={3}
              sx={{ mb: 2 }}
            />
          </Grid>
        </Grid>

        <Box display="flex" gap={2} justifyContent="flex-end" mt={3}>
          {editMode ? (
            <>
              <Button
                variant="outlined"
                onClick={() => setEditMode(false)}
                disabled={saving}
              >
                Cancel
              </Button>
              <Button
                variant="contained"
                startIcon={<Save />}
                onClick={handleSave}
                disabled={saving}
              >
                {saving ? <CircularProgress size={24} /> : 'Save Changes'}
              </Button>
            </>
          ) : (
            <Button
              variant="contained"
              startIcon={<Edit />}
              onClick={() => setEditMode(true)}
            >
              Edit Profile
            </Button>
          )}
        </Box>

        <Divider sx={{ my: 3 }} />

        <Typography variant="h6" gutterBottom>
          Advanced Actions
        </Typography>
        <Box display="flex" gap={2}>
          <Button
            variant="outlined"
            color="warning"
            onClick={handleReenrollUser}
          >
            Re-enroll User
          </Button>
          <Button
            variant="outlined"
            color="error"
            onClick={handleRevokeUser}
          >
            Revoke User
          </Button>
        </Box>
      </Paper>
    </Container>
  );
};

export default UserProfile;
