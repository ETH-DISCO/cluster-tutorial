import numpy as np
import struct
from array import array
import os
from os.path import join
import matplotlib.pyplot as plt
import torch
from typing import Tuple

class MnistDataloader(object):
    def __init__(self, training_images_filepath, training_labels_filepath,
                 test_images_filepath, test_labels_filepath):
        self.training_images_filepath = training_images_filepath
        self.training_labels_filepath = training_labels_filepath
        self.test_images_filepath = test_images_filepath
        self.test_labels_filepath = test_labels_filepath
    
    def read_images_labels(self, images_filepath, labels_filepath):        
        labels = []
        with open(labels_filepath, 'rb') as file:
            magic, size = struct.unpack(">II", file.read(8))
            if magic != 2049:
                raise ValueError('Magic number mismatch, expected 2049, got {}'.format(magic))
            labels = array("B", file.read())        
        labels = np.array(labels, dtype=np.int64)
        with open(images_filepath, 'rb') as file:
            magic, size, rows, cols = struct.unpack(">IIII", file.read(16))
            if magic != 2051:
                raise ValueError('Magic number mismatch, expected 2051, got {}'.format(magic))
            image_data = array("B", file.read())        
        images = np.stack([
            np.array(image_data[i * rows * cols:(i + 1) * rows * cols]).reshape(28, 28)
            for i in range(size)
        ])
        # for i in range(size):
        #     img = np.array(image_data[i * rows * cols:(i + 1) * rows * cols])
        #     img = img.reshape(28, 28)
        #     images[i][:] = img            
        
        return images, labels
            
    def load_data(self):
        x_train, y_train = self.read_images_labels(self.training_images_filepath, self.training_labels_filepath)
        x_test, y_test = self.read_images_labels(self.test_images_filepath, self.test_labels_filepath)

        return (x_train, y_train),(x_test, y_test) 
    

# Get environment variable MNIST_DATASET_PATH if it exists
def get_data_path():
    MNIST_DATASET_PATH = os.getenv('MNIST_DATASET_PATH')
    if MNIST_DATASET_PATH is None:
        MNIST_DATASET_PATH = 'mnist-data/'
    return MNIST_DATASET_PATH

def get_data(data_path: str | None = None):
    if data_path is None:
        data_path = get_data_path()
    training_images_filepath = join(data_path, 'train-images.idx3-ubyte')
    training_labels_filepath = join(data_path, 'train-labels.idx1-ubyte')
    test_images_filepath = join(data_path, 't10k-images.idx3-ubyte')
    test_labels_filepath = join(data_path, 't10k-labels.idx1-ubyte')
    mnist_dataloader = MnistDataloader(training_images_filepath, training_labels_filepath, test_images_filepath, test_labels_filepath)
    return mnist_dataloader.load_data()

def get_dataloader(data_path: str | None = None, batch_size: int = 32, shuffle: bool = True) -> Tuple[torch.utils.data.DataLoader, torch.utils.data.DataLoader]:
    (x_train, y_train), (x_test, y_test) = get_data(data_path=data_path)
    train_loader = torch.utils.data.DataLoader(
        torch.utils.data.TensorDataset(torch.tensor(x_train, dtype=torch.float32).unsqueeze(1), torch.tensor(y_train, dtype=torch.int64)),
        batch_size=batch_size, shuffle=shuffle)
    test_loader = torch.utils.data.DataLoader(
        torch.utils.data.TensorDataset(torch.tensor(x_test, dtype=torch.float32).unsqueeze(1), torch.tensor(y_test, dtype=torch.int64)),
        batch_size=batch_size, shuffle=shuffle)
    return train_loader, test_loader


def main():
    (x_train, y_train), (x_test, y_test) = get_data()
    print('x_train.shape:', np.array(x_train).shape)
    print('y_train.shape:', np.array(y_train).shape)
    print('x_test.shape:', np.array(x_test).shape)
    print('y_test.shape:', np.array(y_test).shape)

    # Display the first 10 images

    fig, ax = plt.subplots(1, 10, figsize=(10, 1))
    print('Labels:', y_train[0:10])
    for i in range(10):
        ax[i].set_axis_off()
        ax[i].imshow(x_train[i], cmap='gray')
    plt.show()


