import axios from 'axios';

// Create axios instance with default configuration
const api = axios.create({
  baseURL: process.env.REACT_APP_API_URL || 'http://localhost:3001',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor to add auth token
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor to handle errors
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Token expired or invalid
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// Authentication API
export const authAPI = {
  login: (credentials) => api.post('/login', credentials),
  register: (userData) => api.post('/register', userData),
  logout: () => api.post('/logout'),
  enrollAdmin: (adminData) => api.post('/enrollAdmin', adminData),
};

// User API
export const userAPI = {
  getUser: () => api.get('/user'),
  editProfile: (profileData) => api.post('/user/edit', profileData),
  revokeUser: (userData) => api.post('/user/revoke', userData),
  reenrollUser: (userData) => api.post('/user/reenroll', userData),
};

// Contract/Chaincode API
export const contractAPI = {
  create: (productData) => api.post('/contract/create', productData),
  update: (productData) => api.post('/contract/update', productData),
  dongGoi: (packageData) => api.post('/contract/dongGoi', packageData),
  transfer: (transferData) => api.post('/contract/tranfer', transferData),
  getById: (id) => api.get(`/contract/get?id=${id}`),
  getHashValue: (id) => api.get(`/contract/getHashValue?id=${id}`),
  getListSanPham: (params) => api.get('/contract/getListSanPham', { params }),
  getListSanPhamChiaNho: (params) => api.get('/contract/getListSanPhamChiaNho', { params }),
  searchSanPham: (searchQuery) => api.get(`/contract/searchSanPham?query=${searchQuery}`),
  getHistory: (id) => api.get(`/contract/history?id=${id}`),
  getHistoryComplete: (maDongGoi) => api.get(`/contract/history/complete?maDongGoi=${maDongGoi}`),
};

// Offchain API
export const offchainAPI = {
  uploadDescriptions: (formData) => api.post('/offchain/uploadDescriptions', formData, {
    headers: {
      'Content-Type': 'multipart/form-data',
    },
  }),
};

export default api;
